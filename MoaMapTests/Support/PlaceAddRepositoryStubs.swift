import Foundation
@testable import MoaMap

@MainActor
final class PlaceSearchRepositoryStub: PlaceSearchRepository {
    var result: (String) async throws -> [PlaceCandidate] = { _ in [] }
    private(set) var queries: [String] = []

    func search(query: String) async throws -> [PlaceCandidate] {
        queries.append(query)
        return try await result(query)
    }
}

@MainActor
final class PlaceAddRepositoryStub: PlaceAddRepository {
    var upload: ([UploadImage]) async throws -> [String] = { photos in photos.indices.map { "https://file/\($0)" } }
    var add: (NewPlace) async throws -> Void = { _ in }
    private(set) var uploadCalls = 0
    private(set) var added: [NewPlace] = []

    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] {
        uploadCalls += 1
        return try await upload(photos)
    }

    func addPlace(mapID: Int64, newPlace: NewPlace) async throws {
        added.append(newPlace)
        try await add(newPlace)
    }
}

extension PlaceCandidate {
    static func fixture(id: String = "1") -> PlaceCandidate {
        PlaceCandidate(
            kakaoPlaceID: id, name: "카페 \(id)", address: "성수동", roadAddress: nil,
            latitude: 37.5, longitude: 127.0, category: "음식점 > 카페", placeURL: nil
        )
    }
}
