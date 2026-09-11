import Foundation

/// Normalizes OTP codes from email (e.g. `0 5 0 8 0 5 8 6` → `05080586`) for Supabase GoTrue verify.
/// Tokens are always handled as `String` — never converted to `Int` (leading zeros must survive).
enum EmailOTPCodeNormalizer {
    static let minLength = 6
    static let maxLength = 10

    static func normalize(_ raw: String) -> String {
        let collapsed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        let digits = collapsed.filter { character in
            character >= "0" && character <= "9"
        }
        return String(digits.prefix(maxLength))
    }

    static func isValidLength(_ normalized: String) -> Bool {
        let count = normalized.count
        return count >= minLength && count <= maxLength
    }

#if DEBUG
    /// Masks middle digits for console logs, e.g. `05080586` → `05******86`.
    static func masked(_ normalized: String) -> String {
        guard normalized.count > 4 else {
            return String(repeating: "*", count: normalized.count)
        }
        let prefix = normalized.prefix(2)
        let suffix = normalized.suffix(2)
        let maskedCount = max(0, normalized.count - 4)
        return "\(prefix)\(String(repeating: "*", count: maskedCount))\(suffix)"
    }
#endif
}
