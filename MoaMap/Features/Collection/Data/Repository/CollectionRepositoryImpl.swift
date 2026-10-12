import Foundation

@MainActor
final class CollectionRepositoryImpl: CollectionRepository {
    static let pageSize = 100
    /// 서버가 `last` 를 잘못 내려도 무한히 돌지 않게 하는 상한. 서버의 순서 변경 상한(300개)을 넉넉히 덮는다.
    static let maxPages = 5

    private let client: APIClient
    private let uploader: any ImageUploader

    init(client: APIClient, uploader: any ImageUploader) {
        self.client = client
        self.uploader = uploader
    }

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        var maps: [MyMap] = []
        for page in 0..<Self.maxPages {
            let request = APIRequest(
                path: ["api", "v1", "maps", "me"],
                queryItems: [
                    URLQueryItem(name: "type", value: type.serverValue),
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.pageSize))
                ]
            )
            let response = try await client.send(request, as: MyMapPageResponse.self)
            let content = response.content ?? []
            maps += content.map { $0.toDomain() }
            // 빈 페이지도 끝으로 본다. `last` 하나만 믿으면 루프가 끝나지 않을 수 있다.
            if response.last ?? true || content.isEmpty { break }
        }
        return maps
    }

    func updateMapOrder(type: CollectionMapType, mapIDs: [Int64]) async throws {
        let request = APIRequest(
            path: ["api", "v1", "maps", "me", "order"],
            method: .patch,
            jsonBody: try JSONEncoder().encode(MapOrderUpdateRequest(type: type.serverValue, mapIds: mapIDs))
        )
        try await client.sendWithoutResponse(request)
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

    func updateMap(mapID: Int64, _ update: MapUpdate) async throws {
        let request = APIRequest(
            path: ["api", "v1", "maps", String(mapID)],
            method: .patch,
            jsonBody: try JSONEncoder().encode(MapUpdateRequest(update))
        )
        try await client.sendWithoutResponse(request)
    }
}

private nonisolated extension CollectionMapType {
    var serverValue: String { self == .community ? "COMMUNITY" : "PRIVATE" }
}
