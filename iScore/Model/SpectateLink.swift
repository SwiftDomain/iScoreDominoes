//
//  SpectateLink.swift
//  iScore
//
//  The phone-to-phone connection for a shared game: MultipeerConnectivity over
//  Wi-Fi and Bluetooth, encrypted, no internet. This file only moves bytes —
//  who is let in and what goes out is `SpectatePolicy`, and what a guest makes
//  of what arrives is `SpectateGuest`.
//

import Foundation
import MultipeerConnectivity
import Observation

enum SpectateService {

    /// Bonjour service name; `Info.plist` declares `_iscore-live._tcp` and `._udp`.
    static let type = "iscore-live"

    /// What other phones see this one as: the owner's name, or the app's.
    static func displayName(from defaults: UserDefaults = .standard) -> String {
        fitted((defaults.string(forKey: OwnerIdentity.nameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// `MCPeerID` raises on a name over 63 UTF-8 bytes. Cut on a character
    /// boundary, so an emoji name or one from before the length cap is safe.
    static func fitted(_ name: String, maxBytes: Int = 63) -> String {
        var result = ""
        for character in name {
            guard result.utf8.count + String(character).utf8.count <= maxBytes else { break }
            result.append(character)
        }
        return result.isEmpty ? "iScore" : result
    }
}

// MARK: - Scorekeeper

/// Advertises the shared game and sends every change to the phones watching.
/// The app owns one, so sharing survives leaving the Game screen.
@MainActor @Observable
final class SpectateHostLink: NSObject {

    private(set) var code: JoinCode?
    private(set) var watching = 0
    private(set) var shared: SpectatePolicy.SharedGame?

    var isSharing: Bool { code != nil }
    var sharedGameID: UUID? { shared?.id }
    var keepsAwake: Bool { isSharing && SpectatePolicy.keepsHostAwake(shared) }

    @ObservationIgnored private let displayName: String
    /// Made on first use, not at launch: the app owns a host link from start.
    @ObservationIgnored private lazy var peer = MCPeerID(displayName: displayName)
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    /// The latest snapshot, for a guest who connects after it was sent.
    @ObservationIgnored private var lastSnapshot: Data?

    init(displayName: String = SpectateService.displayName()) {
        self.displayName = displayName
        super.init()
    }

    /// Picks a code the first time, starts advertising, and sends the game if
    /// the policy lets it out. Opening the share sheet from an old game while
    /// sharing only shows the code; it never re-targets the broadcast.
    func start(sharing game: Game) {
        if code == nil {
            let code = JoinCode.random()
            let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
            let advertiser = MCNearbyServiceAdvertiser(
                peer: peer,
                discoveryInfo: SpectatePolicy.discoveryInfo(for: code),
                serviceType: SpectateService.type
            )
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.code = code
            self.session = session
            self.advertiser = advertiser
        }
        publish(game)
    }

    /// Sends `game` to everyone watching, when the policy says it should go out.
    func publish(_ game: Game) {
        guard isSharing, SpectatePolicy.shouldPublish(game, shared: shared) else { return }
        shared = SpectatePolicy.SharedGame(game)
        guard let data = try? SpectateSnapshot(game: game).encoded() else { return }
        lastSnapshot = data
        send(data, to: session?.connectedPeers ?? [])
    }

    /// Advertising does not outlive the app going to the background; coming
    /// back starts it again so guests who kept looking find this phone.
    func resume() {
        guard isSharing else { return }
        advertiser?.stopAdvertisingPeer()
        advertiser?.startAdvertisingPeer()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        advertiser = nil
        session = nil
        lastSnapshot = nil
        code = nil
        shared = nil
        watching = 0
    }

    private func send(_ data: Data, to peers: [MCPeerID]) {
        guard let session, !peers.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }

    fileprivate func invitation(from context: Data?) -> MCSession? {
        guard let code, SpectatePolicy.acceptsInvitation(context: context, code: code) else { return nil }
        return session
    }

    fileprivate func peer(_ peerID: MCPeerID, changedTo state: MCSessionState) {
        watching = session?.connectedPeers.count ?? 0
        if state == .connected, let lastSnapshot {
            send(lastSnapshot, to: [peerID])
        }
    }
}

extension SpectateHostLink: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                didReceiveInvitationFromPeer peerID: MCPeerID,
                                withContext context: Data?,
                                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            let session = self.invitation(from: context)
            invitationHandler(session != nil, session)
        }
    }
}

extension SpectateHostLink: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in self.peer(peerID, changedTo: state) }
    }

    // Guests never send anything the scorekeeper should act on.
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Guest

/// Finds the host advertising a code and follows what it sends. Keeps
/// browsing after a drop, which is how a guest reconnects on its own.
@MainActor @Observable
final class SpectateGuestLink: NSObject {

    private(set) var phase: SpectateGuest.Phase = .searching

    @ObservationIgnored private let displayName: String
    @ObservationIgnored private lazy var peer = MCPeerID(displayName: displayName)
    @ObservationIgnored private var code: JoinCode?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// One invitation in flight at a time.
    @ObservationIgnored private var isInviting = false

    init(displayName: String = SpectateService.displayName()) {
        self.displayName = displayName
        super.init()
    }

    func join(_ code: JoinCode) {
        self.code = code
        startLooking()
    }

    /// A fresh session and a fresh browse. Restarting the browse is what makes
    /// Multipeer report the host again after a drop or a failed invitation.
    private func startLooking() {
        stopLooking()
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: SpectateService.type)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.session = session
        self.browser = browser
    }

    /// Stops looking. The last score stays, marked lost rather than live.
    func leave() {
        code = nil
        stopLooking()
        phase = SpectateGuest.reduce(phase, .disconnected)
    }

    private func stopLooking() {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        browser = nil
        session = nil
        isInviting = false
    }

    /// Callbacks from a session or browser already replaced are ignored, so a
    /// late drop from an old session never marks a live guest lost.
    private func isCurrent(_ id: ObjectIdentifier, _ object: AnyObject?) -> Bool {
        object.map { ObjectIdentifier($0) == id } ?? false
    }

    fileprivate func found(_ peerID: MCPeerID, info: [String: String]?, browserID: ObjectIdentifier) {
        guard isCurrent(browserID, browser), let code, let session, let browser,
              SpectatePolicy.shouldInvite(discoveryInfo: info, code: code,
                                          busy: isInviting || !session.connectedPeers.isEmpty) else { return }
        isInviting = true
        browser.invitePeer(peerID, to: session, withContext: SpectatePolicy.invitationContext(for: code), timeout: 10)
    }

    fileprivate func session(_ sessionID: ObjectIdentifier, changedTo state: MCSessionState) {
        guard isCurrent(sessionID, session) else { return }
        switch state {
        case .connected:
            isInviting = false
        case .notConnected:
            // A drop, or an invitation that failed or timed out. Look again
            // after a beat; `leave()` clears the code, which cancels this.
            isInviting = false
            phase = SpectateGuest.reduce(phase, .disconnected)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.code != nil, self.isCurrent(sessionID, self.session) else { return }
                self.startLooking()
            }
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    fileprivate func received(_ data: Data, sessionID: ObjectIdentifier) {
        guard isCurrent(sessionID, session) else { return }
        phase = SpectateGuest.reduce(phase, .received(data))
    }
}

extension SpectateGuestLink: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let browserID = ObjectIdentifier(browser)
        Task { @MainActor in self.found(peerID, info: info, browserID: browserID) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension SpectateGuestLink: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let sessionID = ObjectIdentifier(session)
        Task { @MainActor in self.session(sessionID, changedTo: state) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let sessionID = ObjectIdentifier(session)
        Task { @MainActor in self.received(data, sessionID: sessionID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
