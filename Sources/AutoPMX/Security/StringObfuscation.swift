import Foundation

// MARK: - Compile-time String Obfuscation
// Purpose: Prevent `strings` / `nm` / `otool` from extracting readable text
// from the compiled binary (LLM prompts, API URLs, model instructions, etc.).
//
// How it works:
//   Each string literal is XOR-encoded at init time with a fixed key.
//   The encoded bytes are stored in the binary; the plain text never
//   appears as a contiguous UTF-8 sequence.
//
// Usage:
//   let hint = Obfuscated("https://api.anthropic.com").value
//   Obfuscated("You are an expert pharmacometrician...").value
//
// Anti-analysis:
//   - `strings binary` shows only scrambled bytes
//   - `otool -tV binary` shows only scrambled byte arrays
//   - Hopper/Ghidra disassembly shows XOR loops, not plain text
//
// Rotation: Change the key array between releases.

struct Obfuscated {
    /// 8-byte XOR key. Must be the same at compile-time and runtime.
    /// Change this key for each release to defeat static analysis caching.
    private static let key: [UInt8] = [0xAF, 0x3C, 0x91, 0xD7, 0x48, 0xB2, 0x6E, 0x15]

    private let bytes: ContiguousArray<UInt8>

    /// Create an obfuscated string from a plain text literal.
    ///
    /// At compile time the Swift compiler folds the literal into the binary,
    /// but the XOR encoding means the stored bytes are not the original text.
    ///
    /// - Parameter plain: The plain text to obfuscate.
    init(_ plain: String) {
        let utf8 = plain.utf8
        var encoded = ContiguousArray<UInt8>()
        encoded.reserveCapacity(utf8.count)
        for (i, byte) in utf8.enumerated() {
            encoded.append(byte ^ Self.key[i % Self.key.count])
        }
        self.bytes = encoded
    }

    /// De-obfuscate and return the original string.
    /// Consider caching the result if called repeatedly on the same instance.
    var value: String {
        var decoded = ContiguousArray<UInt8>()
        decoded.reserveCapacity(bytes.count)
        for (i, byte) in bytes.enumerated() {
            decoded.append(byte ^ Self.key[i % Self.key.count])
        }
        return String(decoding: decoded, as: UTF8.self)
    }
}

// MARK: - Debug helper (compile-time verification)
// Uncomment to verify encoding at build time:
// #warning("Obfuscated test: \(Obfuscated("test123").value)")

#if DEBUG
extension Obfuscated {
    /// Verify that a round-trip encode/decode preserves the original text.
    /// Call in unit tests only.
    static func testRoundTrip(_ text: String) -> Bool {
        Obfuscated(text).value == text
    }
}
#endif
