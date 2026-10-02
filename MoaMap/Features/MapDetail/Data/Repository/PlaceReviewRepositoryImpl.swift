import Foundation

@MainActor
final class PlaceReviewRepositoryImpl: PlaceReviewRepository {
    /// 서버 상한과 같은 값이라 왕복이 가장 적다.
    private static let pageSize = 100
    private static let maxPages = 20
    /// 프로필 벌크 조회의 서버 상한.
    private static let profileChunkSize = 100
    /// 화면에서 별점을 없앴지만 서버는 1~5 를 필수로 받는다.
    static let fixedRating = 5

    private let client: APIClient
    private let uploader: any ImageUploader
    private let timeZone: TimeZone

    init(client: APIClient, uploader: any ImageUploader, timeZone: TimeZone) {
        self.client = client
        self.uploader = uploader
        self.timeZone = timeZone
    }

    func fetchReviews(placeID: Int64) async throws -> [PlaceReview] {
        var responses: [PlaceReviewResponse] = []
        for page in 0..<Self.maxPages {
            let request = APIRequest(
                path: path(placeID),
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.pageSize)),
                    // 정렬을 안 주면 오래된 것부터 내려온다.
                    URLQueryItem(name: "sort", value: "createdAt,desc")
                ]
            )
            let response = try await client.send(request, as: PlaceReviewPageResponse.self)
            let content = response.content ?? []
            responses += content
            if response.last ?? true || content.isEmpty { break }
        }
        guard !responses.isEmpty else { return [] }
        let names = try await fetchNicknames(responses.compactMap(\.userId))
        return responses.map { $0.toDomain(authorName: $0.userId.flatMap { names[$0] }, timeZone: timeZone) }
    }

    func createReview(placeID: Int64, content: String, photo: UploadImage?) async throws {
        let imageURL = try await photo.asyncMap { try await upload($0, placeID: placeID) }
        let body = PlaceReviewCreateRequest(
            rating: Self.fixedRating,
            // 사진만 남기는 것도 받아 준다. 빈 문자열 대신 자리를 비워 보낸다.
            content: content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content,
            imageUrls: imageURL.map { [$0] }
        )
        let request = APIRequest(path: path(placeID), method: .post, jsonBody: try JSONEncoder().encode(body))
        try await client.sendWithoutResponse(request)
    }

    func updateReview(placeID: Int64, reviewID: Int64, content: String) async throws {
        // 빈 글도 보낸다. 비워서 안 보내면 서버가 옛 글을 그대로 둔다.
        let request = APIRequest(
            path: path(placeID) + [String(reviewID)], method: .patch,
            jsonBody: try JSONEncoder().encode(PlaceReviewUpdateRequest(content: content))
        )
        try await client.sendWithoutResponse(request)
    }

    func deleteReview(placeID: Int64, reviewID: Int64) async throws {
        try await client.sendWithoutResponse(APIRequest(path: path(placeID) + [String(reviewID)], method: .delete))
    }

    private func path(_ placeID: Int64) -> [String] {
        ["api", "v1", "places", String(placeID), "comments"]
    }

    /// 서버 400 을 받고 나면 이유를 알려줄 수 없어 형식·크기를 먼저 거른다.
    private func upload(_ image: UploadImage, placeID: Int64) async throws -> String {
        try ImageUploadRules.validate(
            contentType: image.contentType, fileSize: image.fileSize, maxFileSize: ImageUploadRules.maxReviewPhotoFileSize
        )
        let body = PlaceReviewPhotoUploadURLRequest(contentType: image.contentType, fileSize: image.fileSize)
        let issued = try await client.send(
            APIRequest(path: path(placeID) + ["photo-upload-url"], method: .post, jsonBody: try JSONEncoder().encode(body)),
            as: PlaceReviewPhotoUploadURLResponse.self
        )
        guard let uploadURL = issued.uploadUrl.flatMap(URL.init(string:)),
              let fileURL = issued.fileUrl, !fileURL.isEmpty else { throw NetworkError.invalidResponse }
        try await uploader.upload(image, to: uploadURL)
        return fileURL
    }

    /// 곁들이는 정보라 실패를 삼킨다. 이름 한 줄 때문에 목록을 통째로 못 여는 게 더 나쁘다.
    private func fetchNicknames(_ authorIDs: [Int64]) async throws -> [Int64: String] {
        var seen = Set<Int64>()
        let ids = authorIDs.filter { $0 > 0 && seen.insert($0).inserted }
        guard !ids.isEmpty else { return [:] }
        do {
            var names: [Int64: String] = [:]
            for start in stride(from: 0, to: ids.count, by: Self.profileChunkSize) {
                let chunk = ids[start..<min(start + Self.profileChunkSize, ids.count)]
                let request = APIRequest(
                    path: ["api", "v1", "users", "profiles"],
                    queryItems: chunk.map { URLQueryItem(name: "ids", value: String($0)) }
                )
                for profile in try await client.send(request, as: [UserProfileResponse].self) {
                    if let id = profile.id, let name = profile.nickname, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        names[id] = name
                    }
                }
            }
            return names
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return [:]
        }
    }
}

private extension Optional {
    func asyncMap<T>(_ transform: (Wrapped) async throws -> T) async rethrows -> T? {
        guard let self else { return nil }
        return try await transform(self)
    }
}
