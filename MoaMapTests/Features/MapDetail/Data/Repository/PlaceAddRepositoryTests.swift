import Foundation
import Testing
@testable import MoaMap

@MainActor
struct PlaceAddRepositoryTests {
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

    private func client(_ log: Log, base: String = "https://example.com/", _ body: @escaping @Sendable (URLRequest) -> String?) throws -> APIClient {
        APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": base])) { request in
            log.add(request)
            let url = try #require(request.url)
            let text = body(request)
            let response = try #require(HTTPURLResponse(url: url, statusCode: text == nil ? 500 : 200, httpVersion: nil, headerFields: nil))
            return (Data((text ?? "{}").utf8), response)
        }
    }

    @Test func 카카오_검색은_키를_실어_보내고_등록할_수_없는_결과를_거른다() async throws {
        let log = Log()
        let sut = KakaoPlaceSearchRepository(client: try client(log, base: "https://dapi.kakao.com/") { _ in
            #"""
            {"documents":[
            {"id":"1","place_name":"카페","address_name":"성수동","road_address_name":"","x":"127.05","y":"37.54","category_name":"음식점 > 카페","place_url":"http://place"},
            {"id":"","place_name":"id 없음","x":"127","y":"37"},
            {"id":"3","place_name":"좌표 없음","x":"NaN","y":"37"},
            {"id":"4","place_name":"범위 밖","x":"200","y":"37"}]}
            """#
        }, restAPIKey: "KEY")
        let result = try await sut.search(query: " 카페 ")
        #expect(result == [PlaceCandidate(
            kakaoPlaceID: "1", name: "카페", address: "성수동", roadAddress: nil, latitude: 37.54, longitude: 127.05,
            category: "음식점 > 카페", placeURL: "http://place"
        )])
        let request = try #require(log.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "KakaoAK KEY")
        #expect(request.url?.path == "/v2/local/search/keyword.json")
        #expect(request.url?.query?.contains("query=%EC%B9%B4%ED%8E%98") == true)
    }

    @Test func 빈_검색어는_부르지_않는다() async throws {
        let log = Log()
        let sut = KakaoPlaceSearchRepository(client: try client(log) { _ in "{}" }, restAPIKey: "KEY")
        #expect(try await sut.search(query: "  ").isEmpty)
        #expect(log.requests.isEmpty)
    }

    @Test func 사진은_한_번에_발급받아_순서대로_올린다() async throws {
        let log = Log()
        let sut = PlaceAddRepositoryImpl(client: try client(log) { _ in
            #"{"success":true,"data":[{"uploadUrl":"https://u/0","fileUrl":"https://f/0"},{"uploadUrl":"https://u/1","fileUrl":"https://f/1"}]}"#
        }, uploader: UploaderSpy(log: log))
        let photos = [UploadImage(data: Data([1]), contentType: "image/png"), UploadImage(data: Data([2, 3]), contentType: "image/jpeg")]
        #expect(try await sut.uploadPhotos(mapID: 7, photos: photos) == ["https://f/0", "https://f/1"])
        #expect(log.uploads.map(\.absoluteString) == ["https://u/0", "https://u/1"])
        let json = try #require(try JSONSerialization.jsonObject(with: log.requests[0].httpBody ?? Data()) as? [String: Any])
        #expect(json["mapId"] as? Int == 7)
        #expect((json["files"] as? [[String: Any]])?.map { $0["fileSize"] as? Int } == [1, 2])
    }

    @Test func 발급_수가_다르면_올리지_않는다() async throws {
        let log = Log()
        let sut = PlaceAddRepositoryImpl(client: try client(log) { _ in
            #"{"success":true,"data":[{"uploadUrl":"https://u/0","fileUrl":"https://f/0"}]}"#
        }, uploader: UploaderSpy(log: log))
        let photos = [UploadImage(data: Data([1]), contentType: "image/png"), UploadImage(data: Data([2]), contentType: "image/png")]
        await #expect(throws: NetworkError.self) { try await sut.uploadPhotos(mapID: 7, photos: photos) }
        #expect(log.uploads.isEmpty)
    }

    @Test func 장소는_카카오_검색_출처로_등록한다() async throws {
        let log = Log()
        let sut = PlaceAddRepositoryImpl(client: try client(log) { _ in #"{"success":true,"data":{"id":1}}"# }, uploader: UploaderSpy(log: log))
        try await sut.addPlace(mapID: 7, newPlace: NewPlace(candidate: .fixture(), tags: [], memo: "  ", photoURLs: []))
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/places")
        let json = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        #expect(json["sourceType"] as? String == "KAKAO_SEARCH")
        #expect(json["kakaoPlaceId"] as? String == "1")
        #expect(json["mapId"] as? Int == 7)
        #expect(json["description"] == nil)
        #expect(json["tags"] == nil)
    }
}
