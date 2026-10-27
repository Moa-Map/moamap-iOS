import Foundation

nonisolated struct ReportRequest: Encodable, Sendable {
    let reason: String
    let detail: String?
}

nonisolated struct BlockedUserResponse: Decodable, Sendable {
    let userId: Int64
    let nickname: String?
    let profileImageUrl: String?

    func toDomain() -> BlockedUser {
        let nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return BlockedUser(
            id: userId,
            nickname: nickname?.isEmpty == false ? nickname : nil,
            profileImageURL: image.flatMap { $0.isEmpty ? nil : URL(string: $0) }
        )
    }
}
