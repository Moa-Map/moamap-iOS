import Foundation
@testable import MoaMap

@MainActor
final class PlaceReviewRepositoryStub: PlaceReviewRepository {
    var reviews: (Int64) async throws -> [PlaceReview] = { _ in [] }
    var create: (Int64, String, UploadImage?) async throws -> Void = { _, _, _ in }
    var update: (Int64, Int64, String) async throws -> Void = { _, _, _ in }
    var delete: (Int64, Int64) async throws -> Void = { _, _ in }
    private(set) var fetchCalls = 0
    private(set) var createCalls = 0
    private(set) var deleteCalls = 0
    private(set) var lastUpdate: (reviewID: Int64, content: String)?

    func fetchReviews(placeID: Int64) async throws -> [PlaceReview] {
        fetchCalls += 1
        return try await reviews(placeID)
    }

    func createReview(placeID: Int64, content: String, photo: UploadImage?) async throws {
        createCalls += 1
        try await create(placeID, content, photo)
    }

    func updateReview(placeID: Int64, reviewID: Int64, content: String) async throws {
        lastUpdate = (reviewID, content)
        try await update(placeID, reviewID, content)
    }

    func deleteReview(placeID: Int64, reviewID: Int64) async throws {
        deleteCalls += 1
        try await delete(placeID, reviewID)
    }
}

extension PlaceReview {
    static func fixture(id: Int64, authorID: Int64 = 1, content: String = "좋아요", imageURLs: [URL] = []) -> PlaceReview {
        PlaceReview(id: id, authorID: authorID, authorName: "모아", content: content, imageURLs: imageURLs)
    }
}
