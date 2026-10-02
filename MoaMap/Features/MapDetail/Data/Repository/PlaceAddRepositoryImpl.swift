import Foundation

@MainActor
final class PlaceAddRepositoryImpl: PlaceAddRepository {
    private let client: APIClient
    private let uploader: any ImageUploader

    init(client: APIClient, uploader: any ImageUploader) {
        self.client = client
        self.uploader = uploader
    }

    /// 서버 400 을 받고 나면 어느 사진이 문제인지 알려줄 수 없어 형식·크기를 먼저 거른다.
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] {
        guard !photos.isEmpty else { return [] }
        for photo in photos {
            try ImageUploadRules.validate(
                contentType: photo.contentType, fileSize: photo.fileSize, maxFileSize: ImageUploadRules.maxPlacePhotoFileSize
            )
        }
        let body = PlacePhotoUploadURLRequest(
            mapId: mapID,
            files: photos.map { .init(contentType: $0.contentType, fileSize: $0.fileSize) }
        )
        let issued = try await client.send(
            APIRequest(path: ["api", "v1", "places", "photo-upload-url"], method: .post, jsonBody: try JSONEncoder().encode(body)),
            as: [PlacePhotoUploadURLResponse].self
        )
        // 발급 수가 다르면 어떤 사진이 빠졌는지 알 수 없다. 조용히 덜 올리지 않는다.
        guard issued.count == photos.count else { throw NetworkError.invalidResponse }
        var fileURLs: [String] = []
        for (photo, url) in zip(photos, issued) {
            guard let uploadURL = url.uploadUrl.flatMap(URL.init(string:)),
                  let fileURL = url.fileUrl, !fileURL.isEmpty else { throw NetworkError.invalidResponse }
            try await uploader.upload(photo, to: uploadURL)
            fileURLs.append(fileURL)
        }
        return fileURLs
    }

    func addPlace(mapID: Int64, newPlace: NewPlace) async throws {
        let candidate = newPlace.candidate
        let memo = newPlace.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = PlaceCreateRequest(
            name: candidate.name,
            address: candidate.address,
            roadAddress: candidate.roadAddress,
            lat: candidate.latitude,
            lng: candidate.longitude,
            category: candidate.category,
            kakaoPlaceId: candidate.kakaoPlaceID,
            // 이 화면은 카카오 검색으로 찾은 장소만 등록한다.
            sourceType: "KAKAO_SEARCH",
            sourceUrl: candidate.placeURL,
            description: memo.isEmpty ? nil : memo,
            mapId: mapID,
            tags: newPlace.tags.isEmpty ? nil : newPlace.tags,
            photoUrls: newPlace.photoURLs.isEmpty ? nil : newPlace.photoURLs
        )
        try await client.sendWithoutResponse(
            APIRequest(path: ["api", "v1", "places"], method: .post, jsonBody: try JSONEncoder().encode(body))
        )
    }
}
