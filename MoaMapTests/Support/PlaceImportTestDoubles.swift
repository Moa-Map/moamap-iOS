import Foundation
@testable import MoaMap

nonisolated struct CaptionExtractorStub: CaptionExtractor {
    var result: CaptionResult = .success("캡션")

    func extract(_ url: String) async throws -> CaptionResult { result }
}

extension ImportedPlace {
    static func fixture(id: String, savable: Bool = true, description: String? = nil) -> ImportedPlace {
        ImportedPlace(
            id: id, name: "장소 \(id)", address: "성수동", latitude: 37.5, longitude: 127.0,
            category: "카페", description: description, kakaoPlaceID: savable ? id : nil,
            sourceType: "INSTAGRAM", sourceURL: "https://www.instagram.com/p/A1/"
        )
    }
}

@MainActor
final class PlaceImportRepositoryStub: PlaceImportRepository {
    var extractInstagram: (String) async throws -> [ImportedPlace] = { _ in [] }
    var extractMapShare: (String) async throws -> [ImportedPlace] = { _ in [] }
    var upload: ([EditedPlace]) async throws -> [String: [String]] = { entries in
        Dictionary(uniqueKeysWithValues: entries.filter { !$0.edit.photos.isEmpty }.map { ($0.place.id, ["https://file/\($0.place.id)"]) })
    }
    var save: ([Int64], [EditedPlace], [String: [String]]) async throws -> PlaceSaveResult = { _, places, _ in
        PlaceSaveResult(created: places.count, duplicate: 0, failed: 0)
    }
    private(set) var extractedURLs: [String] = []
    private(set) var uploadCalls = 0
    private(set) var saveCalls: [(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]])] = []

    func extractInstagramPlaces(url: String) async throws -> [ImportedPlace] {
        extractedURLs.append(url)
        return try await extractInstagram(url)
    }

    func extractMapSharePlaces(url: String) async throws -> [ImportedPlace] {
        extractedURLs.append(url)
        return try await extractMapShare(url)
    }

    func uploadPhotos(mapID: Int64, places: [EditedPlace]) async throws -> [String: [String]] {
        uploadCalls += 1
        return try await upload(places)
    }

    func savePlaces(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]]) async throws -> PlaceSaveResult {
        saveCalls.append((mapIDs, places, photoURLs))
        return try await save(mapIDs, places, photoURLs)
    }
}
