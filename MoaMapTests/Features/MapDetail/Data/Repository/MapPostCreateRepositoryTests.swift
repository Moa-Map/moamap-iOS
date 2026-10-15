import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostCreateRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        private var uploaded: [URL] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        func upload(_ url: URL) { lock.withLock { uploaded.append(url) } }
        var requests: [URLRequest] { lock.withLock { items } }
        var uploads: [URL] { lock.withLock { uploaded } }
    }

    private struct UploaderSpy: ImageUploader {
        let log: Log
        func upload(_ image: UploadImage, to uploadURL: URL) async throws { log.upload(uploadURL) }
    }

    private func repository(_ log: Log, _ body: @escaping @Sendable (URLRequest) -> String) throws -> MapPostRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body(request).utf8), response)
        }
        return MapPostRepositoryImpl(client: client, uploader: UploaderSpy(log: log), timeZone: .gmt)
    }

    private func json(_ request: URLRequest?) throws -> [String: Any] {
        let body = try #require(request?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func 사진을_붙이지_않았으면_발급을_부르지_않는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in "{}" }
        #expect(try await sut.uploadPhotos(mapID: 10, photos: []).isEmpty)
        #expect(log.requests.isEmpty)
    }

    @Test func 사진을_한_장씩_발급받아_올리고_받은_주소를_순서대로_돌려준다() async throws {
        let log = Log()
        let sut = try repository(log) { request in
            let size = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])?["fileSize"] as? Int ?? 0
            return #"{"success":true,"data":{"uploadUrl":"https://s3/\#(size)","fileUrl":"https://cdn/\#(size).jpg"}}"#
        }
        let photos = [UploadImage(data: Data(count: 1), contentType: "image/jpeg"), UploadImage(data: Data(count: 2), contentType: "image/png")]
        let urls = try await sut.uploadPhotos(mapID: 10, photos: photos)
        #expect(urls == ["https://cdn/1.jpg", "https://cdn/2.jpg"])
        #expect(log.uploads == [URL(string: "https://s3/1")!, URL(string: "https://s3/2")!])
        #expect(log.requests.map(\.httpMethod) == ["POST", "POST"])
        #expect(log.requests.first?.url?.path == "/api/v1/maps/10/posts/photo-upload-url")
        #expect(try json(log.requests.last)["contentType"] as? String == "image/png")
    }

    @Test func 한_장이라도_형식이나_크기에_걸리면_아무것도_올리지_않는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in "{}" }
        let tooLarge = UploadImage(data: Data(count: ImageUploadRules.maxPostPhotoFileSize + 1), contentType: "image/jpeg")
        await #expect(throws: ImageUploadError.tooLarge(maxFileSize: ImageUploadRules.maxPostPhotoFileSize)) {
            try await sut.uploadPhotos(mapID: 10, photos: [UploadImage(data: Data(count: 1), contentType: "image/jpeg"), tooLarge])
        }
        #expect(log.requests.isEmpty)
        #expect(log.uploads.isEmpty)
    }

    @Test func 발급_주소가_비어_있으면_올리지_않는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{"uploadUrl":"","fileUrl":""}}"# }
        await #expect(throws: NetworkError.invalidResponse) {
            try await sut.uploadPhotos(mapID: 10, photos: [UploadImage(data: Data(count: 1), contentType: "image/jpeg")])
        }
        #expect(log.uploads.isEmpty)
    }

    @Test func 게시물_작성_요청에_본문과_사진_주소와_장소_태그를_담는다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{"id":1}}"# }
        try await sut.createPost(mapID: 10, post: NewMapPost(
            content: "성수 카페 다녀왔어요",
            photoURLs: ["https://cdn/1.jpg"],
            placeTags: [MapPostPlaceTag(placeID: 5, name: "블루보틀 성수점")]
        ))
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/maps/10/posts")
        let body = try json(request)
        #expect(body["content"] as? String == "성수 카페 다녀왔어요")
        #expect(body["imageUrls"] as? [String] == ["https://cdn/1.jpg"])
        let tags = try #require(body["placeTags"] as? [[String: Any]])
        #expect(tags.count == 1)
        #expect(tags.first?["placeId"] as? Int == 5)
        #expect(tags.first?["name"] as? String == "블루보틀 성수점")
    }
}
