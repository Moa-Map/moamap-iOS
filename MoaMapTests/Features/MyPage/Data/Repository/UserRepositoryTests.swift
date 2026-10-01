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

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { items } }
    func append(_ request: URLRequest) { lock.withLock { items.append(request) } }
}

@MainActor
struct UserRepositoryTests {
    private func repository(
        body: String,
        log: RequestLog = RequestLog(),
        uploader: any ImageUploader = UploaderSpy()
    ) throws -> UserRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.append(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return UserRepositoryImpl(client: client, uploader: uploader)
    }

    private func json(_ request: URLRequest?) throws -> [String: Any] {
        let body = try #require(request?.httpBody)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    @Test func 내_프로필을_변환한다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"""
        {"success":true,"data":{"id":3,"nickname":"모아","email":"moa@example.com","profileImageUrl":" ","introduction":null}}
        """#, log: log)
        let profile = try await sut.fetchMyProfile()
        #expect(profile == MyProfile(id: 3, nickname: "모아", email: "moa@example.com", profileImageURL: nil, introduction: ""))
        #expect(log.requests.first?.httpMethod == "GET")
        #expect(log.requests.first?.url?.path == "/api/v1/users/me")
    }

    @Test func 수정은_PATCH_로_보내고_사진이_없으면_필드를_뺀다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"{"success":true,"data":{"id":3,"nickname":"새이름","introduction":"안녕"}}"#, log: log)
        let profile = try await sut.updateMyProfile(nickname: "새이름", introduction: "안녕", profileImageURL: nil)
        #expect(profile.nickname == "새이름")
        let request = log.requests.first
        #expect(request?.httpMethod == "PATCH")
        #expect(request?.url?.path == "/api/v1/users/me")
        let body = try json(request)
        #expect(body["nickname"] as? String == "새이름")
        #expect(body["introduction"] as? String == "안녕")
        #expect(body["profileImageUrl"] == nil)
    }

    @Test func 사진을_고르면_수정_요청에_주소를_담는다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"{"success":true,"data":{"id":3}}"#, log: log)
        _ = try await sut.updateMyProfile(nickname: "모아", introduction: "", profileImageURL: "https://cdn.example.com/p.png")
        #expect(try json(log.requests.first)["profileImageUrl"] as? String == "https://cdn.example.com/p.png")
    }

    @Test func 사진은_발급받은_주소로_올리고_파일_주소를_돌려준다() async throws {
        let log = RequestLog()
        let uploader = UploaderSpy()
        let sut = try repository(body: #"""
        {"success":true,"data":{"uploadUrl":"https://storage.example.com/up?sig=1","fileUrl":"https://cdn.example.com/p.png","objectKey":"p.png","expiresInSeconds":300}}
        """#, log: log, uploader: uploader)
        let image = UploadImage(data: Data([1, 2, 3]), contentType: "image/png")

        let fileURL = try await sut.uploadProfileImage(image)

        #expect(fileURL == "https://cdn.example.com/p.png")
        let issue = log.requests.first
        #expect(issue?.httpMethod == "POST")
        #expect(issue?.url?.path == "/api/v1/users/profile-upload-url")
        let body = try json(issue)
        #expect(body["contentType"] as? String == "image/png")
        #expect(body["fileSize"] as? Int == 3)
        #expect(uploader.uploads.map(\.0) == [image])
        #expect(uploader.uploads.map(\.1) == [URL(string: "https://storage.example.com/up?sig=1")!])
    }

    @Test func 허용되지_않은_사진은_발급을_요청하지_않는다() async throws {
        let log = RequestLog()
        let uploader = UploaderSpy()
        let sut = try repository(body: "{}", log: log, uploader: uploader)
        await #expect(throws: ImageUploadError.tooLarge(maxFileSize: ImageUploadRules.maxImageFileSize)) {
            _ = try await sut.uploadProfileImage(UploadImage(
                data: Data(count: ImageUploadRules.maxImageFileSize + 1), contentType: "image/jpeg"
            ))
        }
        #expect(log.requests.isEmpty)
        #expect(uploader.uploads.isEmpty)
    }

    @Test func 발급_주소가_비면_올리지_않는다() async throws {
        let uploader = UploaderSpy()
        let sut = try repository(body: #"{"success":true,"data":{"uploadUrl":"","fileUrl":""}}"#, uploader: uploader)
        await #expect(throws: NetworkError.invalidResponse) {
            _ = try await sut.uploadProfileImage(UploadImage(data: Data([1]), contentType: "image/png"))
        }
        #expect(uploader.uploads.isEmpty)
    }
}
