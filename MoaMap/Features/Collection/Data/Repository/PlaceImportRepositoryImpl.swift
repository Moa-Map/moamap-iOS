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

    func extractMapSharePlaces(url: String) async throws -> MapShareExtraction {
        let request = APIRequest(
            path: ["api", "v1", "places", "map-share-extractions"],
            method: .post,
            jsonBody: try JSONEncoder().encode(MapShareExtractRequest(url: url.trimmingCharacters(in: .whitespacesAndNewlines)))
        )
        let response = try await client.send(request, as: MapShareExtractResponse.self)
        let matched = response.matched ?? []
        let unmatched = response.unmatched ?? []
        let places = matched.filter { !($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated().map { $1.toDomain(index: $0, fallbackSource: response.source) }
        let report = MapShareReport(
            declaredCount: response.declaredCount,
            extractedCount: response.extractedCount,
            truncated: response.truncated ?? false,
            missedNames: unmatched.compactMap { $0.name?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        )
        return MapShareExtraction(places: places, report: report)
    }

    /// 발급이 한 번에 5장까지라 장소별로 나눠 부른다. 사진이 없는 장소는 부르지 않는다.
    func uploadPhotos(mapID: Int64, places: [EditedPlace]) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for entry in places where !entry.edit.photos.isEmpty {
            result[entry.place.id] = try await photoUploader.uploadPhotos(mapID: mapID, photos: entry.edit.photos)
        }
        return result
    }

    /// 서버가 요청 하나에 지도 하나만 받는다. 장소는 추출 한도만큼 한 번에 받는다.
    /// 일부 지도만 저장된 채 성공으로 알리면 나머지를 다시 시도할 수 없어 실패는 그대로 던진다.
    func savePlaces(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]]) async throws -> PlaceSaveResult {
        var created = 0, duplicate = 0, failed = 0
        let items = places.map { PlaceBulkItem($0, photoURLs: photoURLs[$0.place.id] ?? []) }
        for mapID in mapIDs {
            let request = APIRequest(
                path: ["api", "v1", "places", "bulk"],
                method: .post,
                jsonBody: try JSONEncoder().encode(PlaceBulkCreateRequest(mapId: mapID, places: items))
            )
            let response = try await client.send(request, as: PlaceBulkCreateResponse.self)
            let mapCreated = response.created ?? 0
            let mapSkipped = response.skipped ?? 0
            created += mapCreated
            duplicate += mapSkipped
            // 새로 들어가지도, 이미 있지도 않은 나머지는 실패다.
            failed += max(0, (response.requested ?? items.count) - mapCreated - mapSkipped)
        }
        return PlaceSaveResult(created: created, duplicate: duplicate, failed: failed)
    }
}
