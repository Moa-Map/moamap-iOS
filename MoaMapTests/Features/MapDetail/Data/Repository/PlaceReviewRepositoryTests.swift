import Foundation
import Testing
@testable import MoaMap

@MainActor
struct PlaceReviewRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        private var uploads = 0
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        func upload() { lock.withLock { uploads += 1 } }
        var requests: [URLRequest] { lock.withLock { items } }
        var uploadCount: Int { lock.withLock { uploads } }
    }

    private struct UploaderSpy: ImageUploader {
        let log: Log
        func upload(_ image: UploadImage, to uploadURL: URL) async throws { log.upload() }
    }

    private func repository(_ log: Log, responses: @escaping @Sendable (URLRequest) -> String?) throws -> PlaceReviewRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let body = responses(request)
            let response = try #require(HTTPURLResponse(url: url, statusCode: body == nil ? 500 : 200, httpVersion: nil, headerFields: nil))
            return (Data((body ?? #"{"success":false,"code":"COMMON_005"}"#).utf8), response)
        }
        return PlaceReviewRepositoryImpl(client: client, uploader: UploaderSpy(log: log), timeZone: TimeZone(identifier: "Asia/Seoul")!)
    }

    private static func query(_ request: URLRequest) -> [URLQueryItem] {
        request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
    }

    @Test func 댓글을_최신순으로_읽고_작성자_닉네임을_채운다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            switch request.url?.path {
            case "/api/v1/places/3/comments":
                return #"""
                {"success":true,"data":{"content":[{"id":1,"userId":7,"content":" 좋아요 ","imageUrls":["","https://p"],"createdAt":"2026-07-30T02:54:12.123456"},
                {"id":2,"userId":8,"content":null,"createdAt":"bad"},{"id":3,"userId":7}],"last":true}}
                """#
            case "/api/v1/users/profiles":
                return #"{"success":true,"data":[{"id":7,"nickname":"모아"},{"id":8,"nickname":" "}]}"#
            default:
                return nil
            }
        }
        let reviews = try await sut.fetchReviews(placeID: 3)
        #expect(reviews.map(\.authorName) == ["모아", nil, "모아"])
        #expect(reviews[0].content == "좋아요")
        #expect(reviews[0].imageURLs == [URL(string: "https://p")!])
        #expect(reviews[0].createdAt == Date(timeIntervalSince1970: 1_785_347_652))
        #expect(reviews[1].content == "")
        #expect(reviews[1].createdAt == nil)
        let list = try #require(log.requests.first)
        #expect(Self.query(list).contains(URLQueryItem(name: "sort", value: "createdAt,desc")))
        let profiles = try #require(log.requests.last)
        #expect(Self.query(profiles) == [URLQueryItem(name: "ids", value: "7"), URLQueryItem(name: "ids", value: "8")])
    }

    @Test func 닉네임_조회가_실패해도_댓글은_돌려준다() async throws {
        let sut = try repository(Log()) { request in
            request.url?.path == "/api/v1/places/3/comments"
                ? #"{"success":true,"data":{"content":[{"id":1,"userId":7,"content":"글"}],"last":true}}"#
                : nil
        }
        #expect(try await sut.fetchReviews(placeID: 3).map(\.authorName) == [nil])
    }

    @Test func 사진을_올린_뒤_고정_별점으로_작성한다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            switch request.url?.path {
            case "/api/v1/places/3/comments/photo-upload-url":
                return #"{"success":true,"data":{"uploadUrl":"https://upload","fileUrl":"https://file"}}"#
            case "/api/v1/places/3/comments":
                return #"{"success":true,"data":{"id":1}}"#
            default:
                return nil
            }
        }
        try await sut.createReview(placeID: 3, content: " ", photo: UploadImage(data: Data([1]), contentType: "image/jpeg"))
        #expect(log.uploadCount == 1)
        let create = try #require(log.requests.last)
        let json = try #require(try JSONSerialization.jsonObject(with: create.httpBody ?? Data()) as? [String: Any])
        #expect(json["rating"] as? Int == 5)
        #expect(json["content"] == nil)
        #expect(json["imageUrls"] as? [String] == ["https://file"])
    }

    @Test func 허용하지_않는_형식은_발급을_요청하지_않는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{}}"# }
        await #expect(throws: ImageUploadError.unsupportedType) {
            try await sut.createReview(placeID: 3, content: "글", photo: UploadImage(data: Data([1]), contentType: "image/gif"))
        }
        #expect(log.requests.isEmpty)
    }

    @Test func 수정은_PATCH_삭제는_DELETE_로_보낸다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true}"# }
        try await sut.updateReview(placeID: 3, reviewID: 5, content: "")
        try await sut.deleteReview(placeID: 3, reviewID: 5)
        #expect(log.requests.map(\.httpMethod) == ["PATCH", "DELETE"])
        #expect(log.requests.map { $0.url?.path } == ["/api/v1/places/3/comments/5", "/api/v1/places/3/comments/5"])
        let json = try #require(try JSONSerialization.jsonObject(with: log.requests[0].httpBody ?? Data()) as? [String: Any])
        #expect(json["content"] as? String == "")
    }

    @Test(arguments: [
        ("2026-07-30T02:54:12", 1_785_347_652.0),
        ("2026-07-30T02:54:12Z", 1_785_380_052.0),
        ("2026-07-30T02:54:12+09:00", 1_785_347_652.0)
    ])
    func 서버_시각을_읽는다(raw: String, epoch: Double) {
        #expect(ServerDateTime.parse(raw, timeZone: TimeZone(identifier: "Asia/Seoul")!) == Date(timeIntervalSince1970: epoch))
    }

    @Test func 형식이_어긋난_시각은_읽지_않는다() {
        let seoul = TimeZone(identifier: "Asia/Seoul")!
        #expect(ServerDateTime.parse("2026-13-30T02:54:12", timeZone: seoul) == nil)
        #expect(ServerDateTime.parse(nil, timeZone: seoul) == nil)
    }
}
