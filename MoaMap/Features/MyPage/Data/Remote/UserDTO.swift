import Foundation

nonisolated struct MyProfileResponse: Decodable, Sendable {
    let id: Int64?
    let nickname: String?
    let email: String?
    let profileImageUrl: String?
    let introduction: String?

    func toDomain() -> MyProfile {
        let image = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MyProfile(
            id: id ?? 0,
            nickname: nickname ?? "",
            email: email ?? "",
            profileImageURL: image.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            introduction: introduction ?? ""
        )
    }
}

/// 부분 수정이다. nil 인 필드는 빠져 서버가 건드리지 않는다.
nonisolated struct UpdateMyProfileRequest: Encodable, Sendable {
    let nickname: String
    let introduction: String
    let profileImageUrl: String?
}

nonisolated struct ProfileUploadURLRequest: Encodable, Sendable {
    let contentType: String
    let fileSize: Int
}

nonisolated struct ProfileUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileUrl: String?
}
