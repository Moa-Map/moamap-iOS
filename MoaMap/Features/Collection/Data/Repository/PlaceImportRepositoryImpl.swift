import Foundation

/// 인스타그램은 캡션을 앱이 읽고 장소 해석만 서버에 맡긴다.
@MainActor
final class PlaceImportRepositoryImpl: PlaceImportRepository {
    private let client: APIClient
    private let captionExtractor: any CaptionExtractor
    /// 장소 사진 발급·업로드는 장소 추가와 같다.
    private let photoUploader: any PlaceAddRepository

    init(client: APIClient, captionExtractor: any CaptionExtractor, photoUploader: any PlaceAddRepository) {
        self.client = client
        self.captionExtractor = captionExtractor
        self.photoUploader = photoUploader
    }

    func extractInstagramPlaces(url: String) async throws -> [ImportedPlace] {
        // 캡션을 읽을 때와 서버에 보낼 때 같은 URL 이어야 한다.
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption: String
        switch try await captionExtractor.extract(url) {
        case .success(let text): caption = text
        case .blocked: throw PlaceExtractionError.captionBlocked
        case .unavailable: throw PlaceExtractionError.captionUnavailable
        case .network: throw PlaceExtractionError.captionNetwork
        }
        let request = APIRequest(
            path: ["api", "v1", "places", "instagram-extractions"],
            method: .post,
            jsonBody: try JSONEncoder().encode(InstagramExtractRequest(url: url, description: caption))
        )
        let candidates = try await client.send(request, as: [PlaceCandidateResponse].self)
        // 이름 없는 후보는 카드에 빈 줄로 보인다.
        return candidates.filter { !($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated().map { $1.toDomain(index: $0) }
    }

    func extractMapSharePlaces(url: String) async throws -> [ImportedPlace] {
        let request = APIRequest(
            path: ["api", "v1", "places", "map-share-extractions"],
            method: .post,
            jsonBody: try JSONEncoder().encode(MapShareExtractRequest(url: url.trimmingCharacters(in: .whitespacesAndNewlines)))
        )
        let response = try await client.send(request, as: MapShareExtractResponse.self)
        return (response.matched ?? []).filter { !($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated().map { $1.toDomain(index: $0, fallbackSource: response.source) }
    }

    /// 발급이 한 번에 5장까지라 장소별로 나눠 부른다. 사진이 없는 장소는 부르지 않는다.
    func uploadPhotos(mapID: Int64, places: [EditedPlace]) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for entry in places where !entry.edit.photos.isEmpty {
            result[entry.place.id] = try await photoUploader.uploadPhotos(mapID: mapID, photos: entry.edit.photos)
        }
        return result
    }

    /// 서버가 요청 하나에 지도 하나만 받는다. 일부 지도만 저장된 채 성공으로 알리면 나머지를 다시 시도할 수 없어 실패는 그대로 던진다.
    func savePlaces(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]]) async throws -> PlaceSaveResult {
        var created = 0, duplicate = 0, failed = 0
        let items = places.map { PlaceBulkItem($0, photoURLs: photoURLs[$0.place.id] ?? []) }
        for mapID in mapIDs {
            for start in stride(from: 0, to: items.count, by: PlaceBulkCreateRequest.maxPlaces) {
                let chunk = Array(items[start..<min(start + PlaceBulkCreateRequest.maxPlaces, items.count)])
                let request = APIRequest(
                    path: ["api", "v1", "places", "bulk"],
                    method: .post,
                    jsonBody: try JSONEncoder().encode(PlaceBulkCreateRequest(mapId: mapID, places: chunk))
                )
                let response = try await client.send(request, as: PlaceBulkCreateResponse.self)
                for result in response.results ?? [] {
                    switch result.status {
                    case "CREATED": created += 1
                    case "DUPLICATE": duplicate += 1
                    default: failed += 1
                    }
                }
            }
        }
        return PlaceSaveResult(created: created, duplicate: duplicate, failed: failed)
    }
}
