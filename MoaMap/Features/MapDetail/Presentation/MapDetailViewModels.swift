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
    let posts: MapPostListViewModel
    let postCalendar: MapPostCalendarViewModel
    let postCreate: MapPostCreateViewModel
    let postDetail: MapPostDetailViewModel
    /// 장소 댓글과 로그 댓글은 토스트 자리가 달라 따로 둔다.
    let reviewModeration: ModerationViewModel
    let postModeration: ModerationViewModel
    /// 지도 정보 수정은 열 때마다 그 순간의 지도로 새로 시작한다.
    let makeEditMap: (MapDetail) -> EditMapViewModel
    /// 장소 수정도 열 때마다 그 순간의 장소로 새로 시작한다.
    let makeEditPlace: (MapPlace) -> PlaceEditViewModel
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

@MainActor
final class PreviewMapPostRepository: MapPostRepository {
    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage {
        let photo = URL(string: "https://example.com/1.jpg")!
        return MapPostPage(posts: [
            MapPost(id: 1, authorID: 2, content: "성수 카페 다녀왔어요. 창가 자리가 좋아요", imageURLs: [photo],
                    placeNames: ["블루보틀 성수점"], createdAt: nil),
            MapPost(id: 2, authorID: 3, content: "주말엔 줄이 길어서 평일 오전을 추천해요. 디저트는 금방 떨어지니 일찍 가세요.",
                    imageURLs: [], placeNames: ["연남 책방"], createdAt: nil),
            MapPost(id: 3, authorID: 2, content: "여기 야경 진짜 좋아요", imageURLs: [photo], placeNames: [], createdAt: nil),
            MapPost(id: 4, authorID: 4, content: "장소 태그 없이 남긴 글", imageURLs: [], placeNames: [], createdAt: nil)
        ], isLast: true)
    }
    func fetchPost(mapID: Int64, postID: Int64) async throws -> MapPost {
        try await fetchPosts(mapID: mapID, page: 0, sort: .latest).posts[0]
    }
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] { [] }
    func createPost(mapID: Int64, post: NewMapPost) async throws {}
}

@MainActor
final class PreviewMapPostCommentRepository: MapPostCommentRepository {
    func fetchComments(mapID: Int64, postID: Int64) async throws -> [MapPostComment] {
        [
            MapPostComment(id: 1, authorID: 2, authorName: "이서연", authorImageURL: nil, content: "창가 자리 좋아 보여요!", createdAt: nil),
            MapPostComment(id: 2, authorID: 1, authorName: nil, authorImageURL: nil, content: "평일 오전이 한가해요", createdAt: nil)
        ]
    }
    func createComment(mapID: Int64, postID: Int64, content: String) async throws -> MapPostComment {
        MapPostComment(id: 3, authorID: 1, authorName: nil, authorImageURL: nil, content: content, createdAt: nil)
    }
    func deleteComment(mapID: Int64, postID: Int64, commentID: Int64) async throws {}
}

@MainActor
final class PreviewReportRepository: ReportRepository {
    func report(_ target: ReportTarget, reason: ReportReason, detail: String?) async throws {}
}

@MainActor
final class PreviewBlockRepository: BlockRepository {
    func fetchBlockedUsers() async throws -> [BlockedUser] { [] }
    func block(userID: Int64) async throws {}
    func unblock(userID: Int64) async throws {}
}

nonisolated struct PreviewCurrentUserStore: CurrentUserStore {
    func load() throws -> Int64? { 1 }
    func save(userId: Int64) throws {}
    func clear() throws {}
}

extension MapDetailViewModels {
    static func preview(mapID: Int64) -> MapDetailViewModels {
        let blockedUsers = BlockedUserStore(repository: PreviewBlockRepository())
        return MapDetailViewModels(
            main: MapDetailViewModel(mapID: mapID, repository: PreviewMapDetailRepository(), currentUserStore: PreviewCurrentUserStore()),
            personalMap: PersonalMapAddViewModel(repository: PreviewPersonalMapRepository()),
            review: PlaceReviewViewModel(
                repository: PreviewPlaceReviewRepository(), currentUserStore: PreviewCurrentUserStore(), now: Date.init
            ),
            addPlace: AddPlaceViewModel(
                mapID: mapID, searchRepository: PreviewPlaceSearchRepository(), addRepository: PreviewPlaceAddRepository(),
                sleep: { try await Task.sleep(for: $0) }
            ),
            member: MemberViewModel(mapID: mapID, repository: PreviewMapMemberRepository(), currentUserStore: PreviewCurrentUserStore()),
            activity: MapActivityViewModel(mapID: mapID, repository: PreviewMapActivityRepository(), now: Date.init),
            pending: PendingRequestViewModel(mapID: mapID, repository: PreviewPendingPlaceRepository()),
            posts: MapPostListViewModel(mapID: mapID, repository: PreviewMapPostRepository()),
            postCalendar: MapPostCalendarViewModel(
                mapID: mapID, repository: PreviewMapPostRepository(), timeZone: .current, now: Date.init
            ),
            postCreate: MapPostCreateViewModel(mapID: mapID, repository: PreviewMapPostRepository()),
            postDetail: MapPostDetailViewModel(
                mapID: mapID, repository: PreviewMapPostCommentRepository(), postRepository: PreviewMapPostRepository(),
                currentUserStore: PreviewCurrentUserStore()
            ),
            reviewModeration: ModerationViewModel(reportRepository: PreviewReportRepository(), blockedUsers: blockedUsers),
            postModeration: ModerationViewModel(reportRepository: PreviewReportRepository(), blockedUsers: blockedUsers),
            makeEditMap: { EditMapViewModel(map: $0, repository: PreviewCollectionRepository()) },
            makeEditPlace: {
                PlaceEditViewModel(
                    place: $0, mapID: mapID, repository: PreviewMapDetailRepository(), photoRepository: PreviewPlaceAddRepository()
                )
            }
        )
    }
}
#endif
