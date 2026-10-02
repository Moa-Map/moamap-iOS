import Foundation

/// 지도 상세 한 화면이 함께 쓰는 ViewModel 묶음.
@MainActor
struct MapDetailViewModels {
    let main: MapDetailViewModel
    let personalMap: PersonalMapAddViewModel
    let review: PlaceReviewViewModel
    let addPlace: AddPlaceViewModel
    let member: MemberViewModel
    let activity: MapActivityViewModel
    let pending: PendingRequestViewModel
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

@MainActor
final class PreviewPlaceSearchRepository: PlaceSearchRepository {
    func search(query: String) async throws -> [PlaceCandidate] {
        (1...3).map {
            PlaceCandidate(
                kakaoPlaceID: "\($0)", name: "커피나무 \($0)호점", address: "서울 동작구 상도동 \($0)",
                roadAddress: "서울시 동작구 369", latitude: 37.4963, longitude: 126.9574, category: "음식점 > 카페", placeURL: nil
            )
        }
    }
}

@MainActor
final class PreviewPlaceAddRepository: PlaceAddRepository {
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] { [] }
    func addPlace(mapID: Int64, newPlace: NewPlace) async throws {}
}

@MainActor
final class PreviewMapMemberRepository: MapMemberRepository {
    func fetchMembers(mapID: Int64) async throws -> [MapMember] {
        [
            MapMember(id: 1, name: "김도현", imageURL: nil, role: .owner, placeCount: 12),
            MapMember(id: 2, name: "이서연", imageURL: nil, role: .admin, placeCount: 5),
            MapMember(id: 3, name: "박지훈", imageURL: nil, role: .member, placeCount: 0)
        ]
    }
    func grantAdmin(mapID: Int64, userID: Int64) async throws {}
}

@MainActor
final class PreviewMapActivityRepository: MapActivityRepository {
    func fetchActivities(mapID: Int64) async throws -> [MapActivity] {
        [
            MapActivity(type: .placeAdded, occurredAt: nil, actorName: "민지", actorImageURL: nil, placeID: 1, placeName: "커피나무"),
            MapActivity(type: .reviewCreated, occurredAt: nil, actorName: "준호", actorImageURL: nil, placeID: 1, placeName: "커피나무")
        ]
    }
}

@MainActor
final class PreviewPendingPlaceRepository: PendingPlaceRepository {
    func fetchPendingPlaces(mapID: Int64) async throws -> [PendingPlace] {
        [PendingPlace(id: 1, placeName: "달빛정원", requesterName: "서연", requesterImageURL: nil, requestedAt: nil)]
    }
    func approve(placeID: Int64) async throws {}
    func reject(placeID: Int64) async throws {}
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
            ),
            addPlace: AddPlaceViewModel(
                mapID: mapID, searchRepository: PreviewPlaceSearchRepository(), addRepository: PreviewPlaceAddRepository(),
                sleep: { try await Task.sleep(for: $0) }
            ),
            member: MemberViewModel(mapID: mapID, repository: PreviewMapMemberRepository()),
            activity: MapActivityViewModel(mapID: mapID, repository: PreviewMapActivityRepository(), now: Date.init),
            pending: PendingRequestViewModel(mapID: mapID, repository: PreviewPendingPlaceRepository())
        )
    }
}
#endif
