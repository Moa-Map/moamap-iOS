import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostCommentRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func repository(_ log: Log, _ body: @escaping @Sendable (URLRequest) -> String?) throws -> MapPostCommentRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let text = body(request)
            let response = try #require(HTTPURLResponse(url: url, statusCode: text == nil ? 500 : 200, httpVersion: nil, headerFields: nil))
            return (Data((text ?? "{}").utf8), response)
        }
        return MapPostCommentRepositoryImpl(client: client, timeZone: seoul)
    }

    nonisolated private static func query(_ request: URLRequest) -> [URLQueryItem] {
        request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
    }

    @Test func 오래된_것부터_끝_페이지까지_이어_받는다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            if request.url?.path == "/api/v1/users/profiles" { return #"{"success":true,"data":[]}"# }
            return Self.query(request).contains(URLQueryItem(name: "page", value: "0"))
                ? #"{"success":true,"data":{"content":[{"id":1,"userId":7}],"last":false}}"#
                : #"{"success":true,"data":{"content":[{"id":2,"userId":7}],"last":true}}"#
        }
        let comments = try await sut.fetchComments(mapID: 10, postID: 3)
        #expect(comments.map(\.id) == [1, 2])
        let pages = log.requests.filter { $0.url?.path == "/api/v1/maps/10/posts/3/comments" }
        #expect(pages.count == 2)
        #expect(Self.query(pages[0]).contains(URLQueryItem(name: "sort", value: "createdAt,asc")))
        #expect(Self.query(pages[0]).contains(URLQueryItem(name: "size", value: "100")))
    }

    @Test func 작성자_이름과_사진을_붙이고_같은_사람은_한_번만_묻는다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            if request.url?.path == "/api/v1/users/profiles" {
                return #"{"success":true,"data":[{"id":7,"nickname":"모아","profileImageUrl":"https://p/7.jpg"},{"id":8,"nickname":" "}]}"#
            }
            return #"""
            {"success":true,"data":{"content":[
            {"id":1,"userId":7,"content":" 좋아요 ","createdAt":"2026-07-30T02:54:12"},
            {"id":2,"userId":8,"content":"저도요"},
            {"id":3,"userId":7,"content":"또"}],"last":true}}
            """#
        }
        let comments = try await sut.fetchComments(mapID: 10, postID: 3)
        #expect(comments.first == MapPostComment(
            id: 1, authorID: 7, authorName: "모아", authorImageURL: URL(string: "https://p/7.jpg"),
            content: "좋아요", createdAt: Date(timeIntervalSince1970: 1_785_347_652)
        ))
        #expect(comments[1].authorName == nil)
        let profiles = try #require(log.requests.last)
        #expect(Self.query(profiles) == [URLQueryItem(name: "ids", value: "7"), URLQueryItem(name: "ids", value: "8")])
    }

    @Test func 프로필을_못_받아도_댓글은_보여준다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            request.url?.path == "/api/v1/users/profiles"
                ? nil
                : #"{"success":true,"data":{"content":[{"id":1,"userId":7,"content":"글"}],"last":true}}"#
        }
        let comments = try await sut.fetchComments(mapID: 10, postID: 3)
        #expect(comments == [MapPostComment(id: 1, authorID: 7, authorName: nil, authorImageURL: nil, content: "글", createdAt: nil)])
    }

    @Test func 댓글이_없으면_프로필을_묻지_않는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{"content":[],"last":true}}"# }
        #expect(try await sut.fetchComments(mapID: 10, postID: 3).isEmpty)
        #expect(log.requests.count == 1)
    }

    @Test func 댓글을_남기면_받은_댓글을_돌려준다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{"id":5,"mapPostId":3,"userId":1,"content":"반가워요"}}"# }
        let comment = try await sut.createComment(mapID: 10, postID: 3, content: "반가워요")
        #expect(comment == MapPostComment(id: 5, authorID: 1, authorName: nil, authorImageURL: nil, content: "반가워요", createdAt: nil))
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/maps/10/posts/3/comments")
        let body = try #require(request.httpBody)
        #expect(try JSONSerialization.jsonObject(with: body) as? [String: String] == ["content": "반가워요"])
    }
}
