import Foundation

@MainActor
final class CollectionRepositoryImpl: CollectionRepository {
    private let client: APIClient
    private let uploader: any ImageUploader

    init(client: APIClient, uploader: any ImageUploader) {
        self.client = client
        self.uploader = uploader
    }

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        let request = APIRequest(
            path: ["api", "v1", "maps", "me"],
            queryItems: [
                URLQueryItem(name: "type", value: type == .community ? "COMMUNITY" : "PRIVATE"),
                URLQueryItem(name: "size", value: "20")
            ]
        )
        let response = try await client.send(request, as: MyMapPageResponse.self)
        return (response.content ?? []).map { $0.toDomain() }
    }

    func joinByInviteCode(_ inviteCode: String) async throws {
        let request = APIRequest(
            path: ["api", "v1", "maps", "join"],
            method: .post,
            jsonBody: try JSONEncoder().encode(JoinByInviteCodeRequest(inviteCode: inviteCode.trimmingCharacters(in: .whitespaces)))
        )
        try await client.sendWithoutResponse(request)
    }

    /// 검증 → 발급 → 업로드 순으로 간다.
    func uploadCoverImage(_ image: UploadImage) async throws -> String {
        try ImageUploadRules.validate(contentType: image.contentType, fileSize: image.fileSize)
        let request = APIRequest(
            path: ["api", "v1", "maps", "cover-upload-url"],
            method: .post,
            jsonBody: try JSONEncoder().encode(CoverUploadURLRequest(contentType: image.contentType, fileSize: image.fileSize))
        )
        let issued = try await client.send(request, as: CoverUploadURLResponse.self)
        guard let uploadURL = issued.uploadUrl.flatMap(URL.init(string:)),
              let fileURL = issued.fileUrl, !fileURL.isEmpty else {
            throw NetworkError.invalidResponse
        }
        try await uploader.upload(image, to: uploadURL)
        return fileURL
    }

    func createMap(_ newMap: NewMap) async throws -> CreatedMap {
        let request = APIRequest(
            path: ["api", "v1", "maps"],
            method: .post,
            jsonBody: try JSONEncoder().encode(MapCreateRequest(newMap))
        )
        return try await client.send(request, as: CreatedMapResponse.self).toDomain()
    }
}
