// xcstrings-format — git clean filter for String Catalogs (*.xcstrings).
//
// Xcode rewrites a catalog in its own format whenever it touches it, while
// scripts write ordinary JSON, so the file kept showing as changed with
// nothing changed. This writes the catalog exactly as Xcode does
// (Foundation's pretty-printed, sorted JSON), so git stores one form and an
// Xcode rewrite is byte-for-byte the same file. Content is never changed: a
// real edit — a new string, a translation, a string Xcode marks stale —
// still shows.
//
// Reads stdin, writes stdout; input that isn't JSON passes through untouched.
// Built and installed by scripts/setup-git.sh.

import Foundation

let input = FileHandle.standardInput.readDataToEndOfFile()

guard let catalog = try? JSONSerialization.jsonObject(with: input, options: [.fragmentsAllowed]),
      let output = try? JSONSerialization.data(
          withJSONObject: catalog,
          options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      )
else {
    FileHandle.standardOutput.write(input)
    exit(0)
}
FileHandle.standardOutput.write(output)
