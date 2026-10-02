import Foundation

/// 지도 상세 한 화면이 함께 쓰는 ViewModel 묶음.
@MainActor
struct MapDetailViewModels {
    let main: MapDetailViewModel
    let personalMap: PersonalMapAddViewModel
    let review: PlaceReviewViewModel
}

#if DEBUG
@MainActor
final class PreviewPersonalMapRepository: PersonalMapRepository {
    func addPlace(placeID: Int64) async throws {}
}

@MainActor
final class PreviewPlaceReviewRepository: PlaceReviewRepository {
    func fetchReviews(placeID: Int64) async throws -> [PlaceReview] {
        [PlaceReview(id: 1, authorID: 1, authorName: "민지", content: "분위기가 편안하고 커피 향이 정말 좋았어요.")]
    }
    func createReview(placeID: Int64, content: String, photo: UploadImage?) async throws {}
    func updateReview(placeID: Int64, reviewID: Int64, content: String) async throws {}
    func deleteReview(placeID: Int64, reviewID: Int64) async throws {}
}

nonisolated struct PreviewCurrentUserStore: CurrentUserStore {
    func load() throws -> Int64? { 1 }
    func save(userId: Int64) throws {}
    func clear() throws {}
}

extension MapDetailViewModels {
    static func preview(mapID: Int64) -> MapDetailViewModels {
        MapDetailViewModels(
            main: MapDetailViewModel(mapID: mapID, repository: PreviewMapDetailRepository()),
            personalMap: PersonalMapAddViewModel(repository: PreviewPersonalMapRepository()),
            review: PlaceReviewViewModel(
                repository: PreviewPlaceReviewRepository(), currentUserStore: PreviewCurrentUserStore(), now: Date.init
            )
        )
    }
}
#endif
