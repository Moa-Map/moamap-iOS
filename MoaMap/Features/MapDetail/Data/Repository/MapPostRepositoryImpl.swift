import Foundation

@MainActor
final class MapPostRepositoryImpl: MapPostRepository {
    /// 서버 기본값과 같다.
    nonisolated static let pageSize = 20

    private let client: APIClient
    private let uploader: any ImageUploader
    private let timeZone: TimeZone

    init(client: APIClient, uploader: any ImageUploader, timeZone: TimeZone) {
        self.client = client
        self.uploader = uploader
        self.timeZone = timeZone
    }

    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage {
        let request = APIRequest(
            path: ["api", "v1", "maps", String(mapID), "posts"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(Self.pageSize)),
                // 최신순도 보낸다. 서버 기본값이 바뀌어도 화면의 선택과 어긋나지 않는다.
                URLQueryItem(name: "sort", value: sort == .latest ? "createdAt,desc" : "createdAt,asc")
            ]
        )
        let response = try await client.send(request, as: MapPostPageResponse.self)
        let content = response.content ?? []
        return MapPostPage(
            posts: content.map { $0.toDomain(timeZone: timeZone) },
            // 빈 페이지도 끝으로 본다. `last` 가 잘못 와도 스크롤할 때마다 헛조회가 반복되지 않는다.
            isLast: response.last ?? true || content.isEmpty
        )
    }

    /// 전부 먼저 살펴본 뒤에 올린다. 셋째 사진이 걸렸을 때 앞의 두 장이 이미 올라가 있으면 지울 방법이 없다.
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] {
        for photo in photos {
            try ImageUploadRules.validate(
                contentType: photo.contentType, fileSize: photo.fileSize, maxFileSize: ImageUploadRules.maxPostPhotoFileSize
            )
        }
        var fileURLs: [String] = []
        for photo in photos {
            let body = MapPostPhotoUploadURLRequest(contentType: photo.contentType, fileSize: photo.fileSize)
            let issued = try await client.send(
                APIRequest(
                    path: ["api", "v1", "maps", String(mapID), "posts", "photo-upload-url"],
                    method: .post,
                    jsonBody: try JSONEncoder().encode(body)
                ),
                as: MapPostPhotoUploadURLResponse.self
            )
            guard let uploadURL = issued.uploadUrl.flatMap(URL.init(string:)),
                  let fileURL = issued.fileUrl, !fileURL.isEmpty else { throw NetworkError.invalidResponse }
            try await uploader.upload(photo, to: uploadURL)
            fileURLs.append(fileURL)
        }
        return fileURLs
    }

    func createPost(mapID: Int64, post: NewMapPost) async throws {
        let body = MapPostCreateRequest(
            content: post.content,
            imageUrls: post.photoURLs,
            placeTags: post.placeTags.map { MapPostPlaceTagRequest(placeId: $0.placeID, name: $0.name) }
        )
        try await client.sendWithoutResponse(
            APIRequest(path: ["api", "v1", "maps", String(mapID), "posts"], method: .post, jsonBody: try JSONEncoder().encode(body))
        )
    }
}
