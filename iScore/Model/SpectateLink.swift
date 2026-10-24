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
        let name = (defaults.string(forKey: OwnerIdentity.nameKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "iScore" : name
    }
}

// MARK: - Scorekeeper

/// Advertises the shared game and sends every change to the phones watching.
/// The app owns one, so sharing survives leaving the Game screen.
@MainActor @Observable
final class SpectateHostLink: NSObject {

    private(set) var code: JoinCode?
    private(set) var watching = 0
    private(set) var sharedGameID: UUID?

    var isSharing: Bool { code != nil }

    @ObservationIgnored private let peer: MCPeerID
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    /// The latest snapshot, for a guest who connects after it was sent.
    @ObservationIgnored private var lastSnapshot: Data?

    init(displayName: String = SpectateService.displayName()) {
        peer = MCPeerID(displayName: displayName)
        super.init()
    }

    /// Picks a code the first time, starts advertising, and sends the game.
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
        sharedGameID = game.id
        publish(game)
    }

    /// Sends `game` to everyone watching, when the policy says it should go out.
    func publish(_ game: Game) {
        guard isSharing, SpectatePolicy.shouldPublish(game, sharedGameID: sharedGameID) else { return }
        sharedGameID = SpectatePolicy.sharedGameID(afterPublishing: game, current: sharedGameID)
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
        sharedGameID = nil
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

    @ObservationIgnored private let peer: MCPeerID
    @ObservationIgnored private var code: JoinCode?
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

    init(displayName: String = SpectateService.displayName()) {
        peer = MCPeerID(displayName: displayName)
        super.init()
    }

    func join(_ code: JoinCode) {
        stopLooking()
        self.code = code
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
        stopLooking()
        phase = SpectateGuest.reduce(phase, .disconnected)
    }

    private func stopLooking() {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        browser = nil
        session = nil
    }

    fileprivate func found(_ peerID: MCPeerID, info: [String: String]?) {
        guard let code, let session, let browser,
              session.connectedPeers.isEmpty,
              SpectatePolicy.matches(discoveryInfo: info, code: code) else { return }
        browser.invitePeer(peerID, to: session, withContext: SpectatePolicy.invitationContext(for: code), timeout: 10)
    }

    fileprivate func handle(_ event: SpectateGuest.Event) {
        phase = SpectateGuest.reduce(phase, event)
    }
}

extension SpectateGuestLink: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in self.found(peerID, info: info) }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension SpectateGuestLink: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .notConnected else { return }
        Task { @MainActor in self.handle(.disconnected) }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.handle(.received(data)) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
