import Foundation
import Testing
@testable import MoaMap

private final class UploaderSpy: ImageUploader, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [(UploadImage, URL)] = []
    var uploads: [(UploadImage, URL)] { lock.withLock { calls } }

    func upload(_ image: UploadImage, to uploadURL: URL) async throws {
        lock.withLock { calls.append((image, uploadURL)) }
    }
}

private final class LockedPages: @unchecked Sendable {
    private let lock = NSLock()
    private var pages: [Int] = []
    var values: [Int] { lock.withLock { pages } }
    func append(_ page: Int) { lock.withLock { pages.append(page) } }
}

@MainActor
struct CollectionRepositoryTests {
    private func repository(
        body: String,
        uploader: any ImageUploader = UploaderSpy(),
        inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) throws -> CollectionRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return CollectionRepositoryImpl(client: client, uploader: uploader)
    }

    private nonisolated static func json(_ request: URLRequest) -> [String: Any]? {
        request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    @Test(arguments: [CollectionMapType.community, .private])
    func 참여한_지도를_유형별로_첫_페이지부터_조회한다(type: CollectionMapType) async throws {
        let sut = try repository(body: #"{"success":true,"data":{"content":[]}}"#) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/v1/maps/me")
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
            let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            #expect(query == ["type": type == .community ? "COMMUNITY" : "PRIVATE", "page": "0", "size": "100"])
        }
        #expect(try await sut.fetchMyMaps(type: type).isEmpty)
    }

    @Test func 순서_변경에_필요하도록_마지막_페이지까지_이어서_받는다() async throws {
        let pages = LockedPages()
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
            let page = Int(items.first { $0.name == "page" }?.value ?? "") ?? -1
            pages.append(page)
            let body = page == 0
                ? #"{"success":true,"data":{"content":[{"id":1},{"id":2}],"last":false}}"#
                : #"{"success":true,"data":{"content":[{"id":3}],"last":true}}"#
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        let sut = CollectionRepositoryImpl(client: client, uploader: UploaderSpy())
        #expect(try await sut.fetchMyMaps(type: .private).map(\.id) == [1, 2, 3])
        #expect(pages.values == [0, 1])
    }

    @Test func 순서_변경은_탭과_전체_지도_ID를_순서대로_보낸다() async throws {
        let sut = try repository(body: #"{"success":true,"data":null}"#) { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == "/api/v1/maps/me/order")
            let body = Self.json(request)
            #expect(body?["type"] as? String == "PRIVATE")
            #expect(body?["mapIds"] as? [Int64] == [3, 1, 2])
        }
        try await sut.updateMapOrder(type: .private, mapIDs: [3, 1, 2])
    }

    @Test func 개인지도_구분과_카드_정보를_보존한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
          {"id":1,"name":"나만의 지도","type":"PRIVATE","personal":true,"memberCount":1,"placeCount":4,"imageUrl":"https://example.com/map.png"},
          {"id":2,"name":"친구들과","type":"PRIVATE","personal":false,"memberCount":3,"placeCount":2}
        ]}}
        """#)
        let maps = try await sut.fetchMyMaps(type: .private)
        #expect(maps == [
            MyMap(id: 1, title: "나만의 지도", imageURL: URL(string: "https://example.com/map.png"), memberCount: 1, placeCount: 4, official: false, personal: true),
            MyMap(id: 2, title: "친구들과", imageURL: nil, memberCount: 3, placeCount: 2, official: false, personal: false)
        ])
    }

    @Test func 누락된_선택값과_빈_이름에_기본값을_적용한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[{"id":1},{"id":2,"name":"  ","imageUrl":"  "}]}}
        """#)
        let maps = try await sut.fetchMyMaps(type: .community)
        #expect(maps.map(\.title) == ["이름 없는 지도", "이름 없는 지도"])
        #expect(maps.allSatisfy { $0.imageURL == nil && $0.memberCount == 0 && $0.placeCount == 0 && !$0.personal })
    }

    @Test func 목록_응답의_내_역할을_읽는다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
          {"id":1,"myRole":"OWNER"},{"id":2,"myRole":"ADMIN"},{"id":3,"myRole":"MEMBER"}
        ]}}
        """#)
        #expect(try await sut.fetchMyMaps(type: .community).map(\.role) == [.owner, .admin, .member])
    }

    @Test func 내_역할이_없거나_null이어도_목록을_읽는다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[{"id":1},{"id":2,"myRole":null},{"id":3,"myRole":"UNKNOWN"}]}}
        """#)
        #expect(try await sut.fetchMyMaps(type: .community).map(\.role) == [.none, .none, .none])
    }

    @Test func 초대_코드로_참여할_때_코드를_본문에_담아_보낸다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"id":7,"name":"지도"}}"#) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/maps/join")
            let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: String] }
            #expect(body == ["inviteCode": "VH4YXZ"])
        }
        try await sut.joinByInviteCode(" VH4YXZ ")
    }

    @Test func 초대_코드_오류_코드를_전파한다() async throws {
        let sut = try repository(body: #"{"success":false,"error":{"code":"MAP_007","status":404}}"#)
        await #expect(throws: NetworkError.server(code: "MAP_007", statusCode: 404)) {
            try await sut.joinByInviteCode("WRONG1")
        }
    }

    @Test func 지도_생성은_공백을_정리하고_빈_값은_보내지_않는다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"id":9,"inviteCode":" "}}"#) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/maps")
            let body = Self.json(request)
            #expect(body?["name"] as? String == "성수 카페")
            #expect(body?["visibility"] as? String == "PUBLIC")
            #expect(body?.keys.sorted() == ["name", "visibility"])
        }
        let created = try await sut.createMap(NewMap(name: " 성수 카페 ", description: "  ", visibility: .public, tags: [], imageURL: nil))
        #expect(created == CreatedMap(id: 9, inviteCode: nil))
    }

    @Test func 프라이빗_지도는_초대_코드와_커버_태그를_함께_다룬다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"id":9,"inviteCode":"VH4YXZ"}}"#) { request in
            let body = Self.json(request)
            #expect(body?["visibility"] as? String == "PRIVATE")
            #expect(body?["description"] as? String == "친구들과")
            #expect(body?["imageUrl"] as? String == "https://cdn.example.com/cover.jpg")
            #expect(body?["tags"] as? [String] == ["카페", "성수"])
        }
        let created = try await sut.createMap(NewMap(
            name: "성수", description: "친구들과", visibility: .private,
            tags: ["카페", "성수"], imageURL: "https://cdn.example.com/cover.jpg"
        ))
        #expect(created == CreatedMap(id: 9, inviteCode: "VH4YXZ"))
    }

    @Test func 지도_수정은_PATCH로_전체_값을_보내고_빈_설명과_사진은_뺀다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"id":7}}"#) { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url?.path == "/api/v1/maps/7")
            let body = Self.json(request)
            #expect(body?["name"] as? String == "성수 카페")
            #expect(body?["tags"] as? [String] == [])
            #expect(body?.keys.sorted() == ["name", "tags"])
        }
        try await sut.updateMap(mapID: 7, MapUpdate(name: " 성수 카페 ", description: " ", tags: [], imageURL: nil))
    }

    @Test func 지도_수정은_설명_사진_태그를_그대로_담는다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"id":7}}"#) { request in
            let body = Self.json(request)
            #expect(body?["description"] as? String == "친구들과")
            #expect(body?["imageUrl"] as? String == "https://cdn.example.com/cover.jpg")
            #expect(body?["tags"] as? [String] == ["카페", "성수"])
        }
        try await sut.updateMap(mapID: 7, MapUpdate(
            name: "성수", description: "친구들과", tags: ["카페", "성수"], imageURL: "https://cdn.example.com/cover.jpg"
        ))
    }

    @Test func 커버는_주소를_발급받아_올리고_파일_주소를_돌려준다() async throws {
        let uploader = UploaderSpy()
        let sut = try repository(
            body: #"{"success":true,"data":{"uploadUrl":"https://s3.example.com/put","fileUrl":"https://cdn.example.com/cover.jpg"}}"#,
            uploader: uploader
        ) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/maps/cover-upload-url")
            #expect(Self.json(request)?["contentType"] as? String == "image/png")
            #expect(Self.json(request)?["fileSize"] as? Int == 3)
        }
        let image = UploadImage(data: Data([1, 2, 3]), contentType: "image/png")
        #expect(try await sut.uploadCoverImage(image) == "https://cdn.example.com/cover.jpg")
        #expect(uploader.uploads.map(\.0) == [image])
        #expect(uploader.uploads.map(\.1) == [URL(string: "https://s3.example.com/put")])
    }

    @Test func 커버는_발급_전에_형식과_크기를_거른다() async throws {
        let sut = try repository(body: "") { _ in Issue.record("요청을 보내면 안 된다") }
        await #expect(throws: ImageUploadError.unsupportedType) {
            _ = try await sut.uploadCoverImage(UploadImage(data: Data([1]), contentType: "image/gif"))
        }
        let large = Data(count: ImageUploadRules.maxImageFileSize + 1)
        await #expect(throws: ImageUploadError.tooLarge(maxFileSize: ImageUploadRules.maxImageFileSize)) {
            _ = try await sut.uploadCoverImage(UploadImage(data: large, contentType: "image/jpeg"))
        }
    }

    @Test func 커버_발급_주소가_비면_올리지_않는다() async throws {
        let uploader = UploaderSpy()
        let sut = try repository(body: #"{"success":true,"data":{"uploadUrl":"","fileUrl":""}}"#, uploader: uploader)
        await #expect(throws: NetworkError.invalidResponse) {
            _ = try await sut.uploadCoverImage(UploadImage(data: Data([1]), contentType: "image/jpeg"))
        }
        #expect(uploader.uploads.isEmpty)
    }

    @Test func 서버_오류를_전파한다() async throws {
        let sut = try repository(body: #"{"success":false,"error":{"code":"COMMON_005","status":500}}"#)
        await #expect(throws: NetworkError.server(code: "COMMON_005", statusCode: 500)) {
            try await sut.fetchMyMaps(type: .community)
        }
    }

    @Test func 요청_취소를_전파한다() async throws {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { _ in
            throw CancellationError()
        }
        let sut = CollectionRepositoryImpl(client: client, uploader: UploaderSpy())
        await #expect(throws: CancellationError.self) {
            try await sut.fetchMyMaps(type: .private)
        }
    }
}
