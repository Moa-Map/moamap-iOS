import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private struct NoUploader: ImageUploader {
        func upload(_ image: UploadImage, to uploadURL: URL) async throws {}
    }

    private func repository(_ log: Log = Log(), body: String) throws -> MapPostRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return MapPostRepositoryImpl(client: client, uploader: NoUploader(), timeZone: seoul)
    }

    private func query(_ request: URLRequest?) -> [String: String] {
        let items = request?.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
    }

    @Test func 지도와_페이지와_한_번에_받을_수를_넘긴다() async throws {
        let log = Log()
        let sut = try repository(log, body: #"{"success":true,"data":{"content":[],"last":true}}"#)
        _ = try await sut.fetchPosts(mapID: 7, page: 2, sort: .latest)
        #expect(log.requests.first?.url?.path == "/api/v1/maps/7/posts")
        #expect(log.requests.first?.httpMethod == "GET")
        #expect(query(log.requests.first) == ["page": "2", "size": "20", "sort": "createdAt,desc"])
    }

    @Test func 등록순은_오름차순으로_보낸다() async throws {
        let log = Log()
        let sut = try repository(log, body: #"{"success":true,"data":{"content":[],"last":true}}"#)
        _ = try await sut.fetchPosts(mapID: 7, page: 0, sort: .oldest)
        #expect(query(log.requests.first)["sort"] == "createdAt,asc")
    }

    @Test func 응답을_도메인으로_옮기고_마지막_페이지_여부를_넘긴다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
        {"id":3,"mapId":7,"userId":9,"content":"성수 카페","imageUrls":["https://p/1.jpg"," ","https://p/2.jpg"],
         "placeTags":[{"placeId":1,"name":" 블루보틀 "},{"placeId":2,"name":" "},{"placeId":3}],
         "createdAt":"2026-07-30T02:54:12"}],"last":false}}
        """#)
        let page = try await sut.fetchPosts(mapID: 7, page: 0, sort: .latest)
        #expect(page == MapPostPage(posts: [
            MapPost(
                id: 3, authorID: 9, content: "성수 카페",
                imageURLs: [URL(string: "https://p/1.jpg")!, URL(string: "https://p/2.jpg")!],
                placeNames: ["블루보틀"], createdAt: Date(timeIntervalSince1970: 1_785_347_652)
            )
        ], isLast: false))
    }

    @Test func 본문이_없으면_빈_문자열이고_시각을_못_읽으면_비운다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"content":[{"id":1,"createdAt":"어제"}],"last":true}}"#)
        let post = try #require(try await sut.fetchPosts(mapID: 7, page: 0, sort: .latest).posts.first)
        #expect(post == MapPost(id: 1, authorID: 0, content: "", imageURLs: [], placeNames: [], createdAt: nil))
    }

    @Test(arguments: [
        #"{"success":true,"data":{"content":[],"last":false}}"#,
        #"{"success":true,"data":{"content":[{"id":1}]}}"#
    ])
    func 빈_페이지나_last_가_없으면_마지막으로_본다(body: String) async throws {
        let sut = try repository(body: body)
        #expect(try await sut.fetchPosts(mapID: 7, page: 0, sort: .latest).isLast)
    }
}
