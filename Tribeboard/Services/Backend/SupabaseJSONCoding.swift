import Foundation

enum SupabaseJSONCoding {
    static func makeSupabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                if let date = BackendTimestampParser.parse(string) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognized date string: \(string)"
                )
            }
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected date string or timestamp number."
            )
        }
        return decoder
    }

    static func makeSupabaseEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func encodePayloadJSON<P: Encodable>(_ payload: P) -> String {
        (try? makeSupabaseEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    static func describeDecodingError(_ error: Error) -> String {
        guard let decoding = error as? DecodingError else {
            return error.localizedDescription
        }
        switch decoding {
        case .keyNotFound(let key, let context):
            return "DecodingError.keyNotFound key=\(key.stringValue) path=\(context.codingPath.map(\.stringValue).joined(separator: ".")) \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "DecodingError.typeMismatch expected=\(type) path=\(context.codingPath.map(\.stringValue).joined(separator: ".")) \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "DecodingError.valueNotFound type=\(type) path=\(context.codingPath.map(\.stringValue).joined(separator: ".")) \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "DecodingError.dataCorrupted path=\(context.codingPath.map(\.stringValue).joined(separator: ".")) \(context.debugDescription)"
        @unknown default:
            return decoding.localizedDescription
        }
    }
}
