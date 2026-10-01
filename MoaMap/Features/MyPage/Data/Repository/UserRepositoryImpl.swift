import Foundation

@MainActor
final class UserRepositoryImpl: UserRepository {
    private let client: APIClient
    private let uploader: any ImageUploader

    init(client: APIClient, uploader: any ImageUploader) {
        self.client = client
        self.uploader = uploader
    }

    func fetchMyProfile() async throws -> MyProfile {
        let request = APIRequest(path: ["api", "v1", "users", "me"])
        return try await client.send(request, as: MyProfileResponse.self).toDomain()
    }

    /// 검증 → 발급 → 업로드 순으로 간다.
    func uploadProfileImage(_ image: UploadImage) async throws -> String {
        try ImageUploadRules.validate(contentType: image.contentType, fileSize: image.fileSize)
        let request = APIRequest(
            path: ["api", "v1", "users", "profile-upload-url"],
            method: .post,
            jsonBody: try JSONEncoder().encode(ProfileUploadURLRequest(contentType: image.contentType, fileSize: image.fileSize))
        )
        let issued = try await client.send(request, as: ProfileUploadURLResponse.self)
        guard let uploadURL = issued.uploadUrl.flatMap(URL.init(string:)),
              let fileURL = issued.fileUrl, !fileURL.isEmpty else {
            throw NetworkError.invalidResponse
        }
        try await uploader.upload(image, to: uploadURL)
        return fileURL
    }

    func updateMyProfile(nickname: String, introduction: String, profileImageURL: String?) async throws -> MyProfile {
        let body = UpdateMyProfileRequest(nickname: nickname, introduction: introduction, profileImageUrl: profileImageURL)
        let request = APIRequest(path: ["api", "v1", "users", "me"], method: .patch, jsonBody: try JSONEncoder().encode(body))
        return try await client.send(request, as: MyProfileResponse.self).toDomain()
    }
}
