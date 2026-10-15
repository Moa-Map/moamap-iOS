import Foundation
@testable import MoaMap

/// 정렬마다 페이지 목록을 들고 있다가 요청한 페이지를 돌려준다. 없는 페이지는 빈 마지막 페이지다.
@MainActor
final class MapPostRepositoryStub: MapPostRepository {
    struct Request: Equatable {
        let page: Int
        let sort: MapPostSort
    }

    var pages: [MapPostSort: [MapPostPage]] = [.latest: [MapPostPage(posts: [.fixture(id: 1), .fixture(id: 2)], isLast: true)]]
    /// 이 페이지를 요청하면 실패한다.
    var failingPage: Int?
    /// 두면 조회가 여기서 멈춘다.
    var gate: AsyncGate?
    private(set) var requests: [Request] = []

    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage {
        requests.append(Request(page: page, sort: sort))
        await gate?.wait()
        if page == failingPage { throw NetworkError.http(statusCode: 500) }
        let sortPages = pages[sort] ?? []
        return page < sortPages.count ? sortPages[page] : MapPostPage(posts: [], isLast: true)
    }
}

extension MapPost {
    static func fixture(id: Int64) -> MapPost {
        MapPost(id: id, authorID: 2, content: "글\(id)", imageURLs: [], placeNames: [], createdAt: nil)
    }
}
