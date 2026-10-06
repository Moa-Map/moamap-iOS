import Foundation
import Testing
@testable import MoaMap

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { items } }
    func append(_ request: URLRequest) { lock.withLock { items.append(request) } }

    func bodies() -> [[String: Any]] {
        requests.compactMap { $0.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } }
    }
}

@MainActor
struct PlaceImportRepositoryTests {
    private let log = RequestLog()

    private func repository(
        body: String = #"{"success":true,"data":[]}"#,
        caption: CaptionResult = .success("성수 카페 투어"),
        photoUploader: PlaceAddRepositoryStub = PlaceAddRepositoryStub()
    ) throws -> PlaceImportRepositoryImpl {
        let log = log
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.append(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return PlaceImportRepositoryImpl(client: client, captionExtractor: CaptionExtractorStub(result: caption), photoUploader: photoUploader)
    }

    // MARK: 인스타그램

    @Test(arguments: [
        (CaptionResult.blocked, PlaceExtractionError.captionBlocked),
        (.unavailable, .captionUnavailable),
        (.network, .captionNetwork)
    ])
    func 캡션을_읽지_못하면_서버를_부르지_않고_실패한다(caption: CaptionResult, error: PlaceExtractionError) async throws {
        let sut = try repository(caption: caption)
        await #expect(throws: error) { try await sut.extractInstagramPlaces(url: "https://www.instagram.com/p/A1/") }
        #expect(log.requests.isEmpty)
    }

    @Test func 다듬은_URL과_캡션_전문을_서버로_보낸다() async throws {
        let sut = try repository()
        _ = try await sut.extractInstagramPlaces(url: "  https://www.instagram.com/p/A1/  ")
        #expect(log.requests.first?.url?.path == "/api/v1/places/instagram-extractions")
        #expect(log.requests.first?.httpMethod == "POST")
        #expect(log.bodies().first as? [String: String] == ["url": "https://www.instagram.com/p/A1/", "description": "성수 카페 투어"])
    }

    @Test func 인스타그램_후보를_장소로_바꾸고_이름_없는_후보는_거른다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":[
          {"kakaoPlaceId":"11","name":"카페","category":"카페","address":"성수동 1","roadAddress":"","lat":37.5,"lng":127.1,"sourceUrl":"https://ig"},
          {"name":"  "},
          {"name":"이름만"}
        ]}
        """#)
        let places = try await sut.extractInstagramPlaces(url: "https://www.instagram.com/p/A1/")
        #expect(places.map(\.id) == ["11", "candidate-1"])
        #expect(places[0] == ImportedPlace(
            id: "11", name: "카페", address: "성수동 1", roadAddress: "", latitude: 37.5, longitude: 127.1,
            category: "카페", kakaoPlaceID: "11", sourceType: "INSTAGRAM", sourceURL: "https://ig"
        ))
        #expect(places[0].displayAddress == "성수동 1")
        #expect(!places[1].savable)
    }

    // MARK: 지도 공유

    @Test func 공유_링크는_캡션_없이_서버로_보내고_matched_만_쓴다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"source":"NAVER_MAP","matched":[
          {"kakaoPlaceId":"21","name":"식당","description":"메모","sourceType":null},
          {"name":"매칭만","sourceType":"KAKAO_MAP"},
          {"name":""}
        ],"unmatched":[{"name":"못 찾음"}]}}
        """#, caption: .blocked)
        let places = try await sut.extractMapSharePlaces(url: " https://naver.me/abc ")
        #expect(log.requests.first?.url?.path == "/api/v1/places/map-share-extractions")
        #expect(log.bodies().first as? [String: String] == ["url": "https://naver.me/abc"])
        #expect(places.map(\.id) == ["21", "candidate-1"])
        #expect(places.map(\.sourceType) == ["NAVER_MAP", "KAKAO_MAP"])
        #expect(places[0].description == "메모")
    }

    // MARK: 등록

    private let createdBody = #"{"success":true,"data":{"results":[{"status":"CREATED"},{"status":"DUPLICATE"},{"status":"FAILED"}]}}"#

    @Test func 고른_지도마다_등록하고_결과를_합산한다() async throws {
        let sut = try repository(body: createdBody)
        let entries = [EditedPlace(place: .fixture(id: "1"), edit: PlaceEdit())]
        let result = try await sut.savePlaces(mapIDs: [10, 20], places: entries, photoURLs: [:])
        #expect(log.requests.map(\.url?.path) == ["/api/v1/places/bulk", "/api/v1/places/bulk"])
        #expect(log.bodies().map { $0["mapId"] as? Int } == [10, 20])
        #expect(result == PlaceSaveResult(created: 2, duplicate: 2, failed: 2))
    }

    @Test func 한_번에_보낼_수_있는_수를_넘으면_나눠_보낸다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"results":[]}}"#)
        let entries = (0..<101).map { EditedPlace(place: .fixture(id: "\($0)"), edit: PlaceEdit()) }
        _ = try await sut.savePlaces(mapIDs: [1], places: entries, photoURLs: [:])
        #expect(log.bodies().map { ($0["places"] as? [Any])?.count } == [100, 1])
    }

    @Test func 편집값을_담고_빈_값은_보내지_않는다() async throws {
        let sut = try repository(body: createdBody)
        let edited = EditedPlace(place: .fixture(id: "1"), edit: PlaceEdit(tags: ["카페"], memo: " 좋아요 "))
        let plain = EditedPlace(place: .fixture(id: "2"), edit: PlaceEdit(memo: "  "))
        _ = try await sut.savePlaces(mapIDs: [1], places: [edited, plain], photoURLs: ["1": ["https://file/a"]])
        let items = try #require(log.bodies().first?["places"] as? [[String: Any]])
        #expect(items[0]["kakaoPlaceId"] as? String == "1")
        #expect(items[0]["sourceType"] as? String == "INSTAGRAM")
        #expect(items[0]["description"] as? String == "좋아요")
        #expect(items[0]["tags"] as? [String] == ["카페"])
        #expect(items[0]["photoUrls"] as? [String] == ["https://file/a"])
        #expect(items[1]["description"] == nil && items[1]["tags"] == nil && items[1]["photoUrls"] == nil)
    }

    @Test func 등록에_실패하면_그대로_던진다() async throws {
        let sut = try repository(body: #"{"success":false,"error":{"code":"PLACE_002","status":403,"message":"지도 멤버만 등록할 수 있어요"}}"#)
        await #expect(throws: NetworkError.server(code: "PLACE_002", statusCode: 403, message: "지도 멤버만 등록할 수 있어요")) {
            _ = try await sut.savePlaces(mapIDs: [1], places: [EditedPlace(place: .fixture(id: "1"), edit: PlaceEdit())], photoURLs: [:])
        }
    }

    // MARK: 사진

    @Test func 사진을_붙인_장소만_올리고_장소_id_로_돌려준다() async throws {
        let uploader = PlaceAddRepositoryStub()
        let sut = try repository(photoUploader: uploader)
        let photo = UploadImage(data: Data([1]), contentType: "image/jpeg")
        let entries = [
            EditedPlace(place: .fixture(id: "1"), edit: PlaceEdit(photos: [photo, photo])),
            EditedPlace(place: .fixture(id: "2"), edit: PlaceEdit())
        ]
        let urls = try await sut.uploadPhotos(mapID: 1, places: entries)
        #expect(urls == ["1": ["https://file/0", "https://file/1"]])
        #expect(uploader.uploadCalls == 1)
    }
}
