import Foundation
import Testing
@testable import MoaMap

struct AuthTokenRefresherTests {
    private func refresher(status: Int = 200, body: String) throws -> AuthTokenRefresher {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            #expect(request.url?.path == "/api/v1/auth/token/refresh")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let json = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
            #expect(json == ["refreshToken": "old-refresh"])
            let url = try #require(request.url)
            return (Data(body.utf8), try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)))
        }
        return AuthTokenRefresher(client: client)
    }

    @Test(arguments: ["null", "\"\"", "\"rotated\""])
    func 새_리프레시_토큰이_있을_때만_교체한다(refreshJSON: String) async throws {
        let subject = try refresher(body: "{\"success\":true,\"data\":{\"accessToken\":\"new\",\"refreshToken\":\(refreshJSON)}}")
        let result = try await subject.refresh(refreshToken: "old-refresh")
        #expect(result == .success(AuthToken(accessToken: "new", refreshToken: refreshJSON == "\"rotated\"" ? "rotated" : "old-refresh")))
    }

    @Test(arguments: [400, 401, 403])
    func 서버의_명시적_거부를_구분한다(status: Int) async throws {
        #expect(try await refresher(status: status, body: "{}").refresh(refreshToken: "old-refresh") == .rejected)
    }

    @Test(arguments: ["{\"success\":true,\"data\":{}}", "{\"success\":true,\"data\":{\"accessToken\":\"\"}}", "invalid"])
    func 불완전한_응답은_일시적_실패다(body: String) async throws {
        #expect(try await refresher(body: body).refresh(refreshToken: "old-refresh") == .failed)
    }

    @Test
    func 연결_실패는_실패로_반환하고_취소는_다시_던진다() async throws {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])
        let offline = AuthTokenRefresher(client: APIClient(configuration: configuration) { _ in throw URLError(.notConnectedToInternet) })
        #expect(try await offline.refresh(refreshToken: "old-refresh") == .failed)
        let cancelled = AuthTokenRefresher(client: APIClient(configuration: configuration) { _ in throw CancellationError() })
        await #expect(throws: CancellationError.self) { try await cancelled.refresh(refreshToken: "old-refresh") }
    }
}
