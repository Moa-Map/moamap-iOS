import Foundation
import Testing
@testable import MoaMap

@MainActor
struct AppContainerTests {
    nonisolated private struct Item: Decodable, Sendable, Equatable { let id: Int }

    @Test
    func 주입한_서버와_전송으로_응답을_처리한다() async throws {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/api/"])
        let container = AppContainer(configuration: configuration, tokenStore: MemoryAuthTokenStore(), currentUserStore: MemoryCurrentUserStore()) { request in
            #expect(request.url?.absoluteString == "https://example.com/api/maps")
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(#"{"success":true,"data":{"id":7}}"#.utf8), response)
        }
        let item = try await container.apiClient.send(APIRequest(path: ["maps"]), as: Item.self)
        #expect(item == Item(id: 7))
    }

    @Test
    func 앱_번들의_빌드_설정으로_조립할_수_있다() throws {
        // 앱 호스트의 Info.plist를 실제로 읽어 xcconfig 연결까지 검증한다. 요청은 보내지 않는다.
        _ = try AppContainer(bundle: .main)
    }

    @Test
    func 주입한_Apple_인증으로_로그인하고_세션을_저장한다() async throws {
        let tokens = MemoryAuthTokenStore()
        let users = MemoryCurrentUserStore()
        let nonce = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG"
        let container = AppContainer(
            configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]),
            tokenStore: tokens, currentUserStore: users,
            appleLogin: { received in
                #expect(received == nonce)
                return AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: nil)
            }
        ) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body: String
            if request.url?.path == "/api/v1/auth/apple/nonce" {
                body = "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}"
            } else {
                #expect(request.url?.path == "/api/v1/auth/apple/login")
                let payload = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
                #expect(payload == ["identityToken": "identity", "authorizationCode": "code", "nonce": nonce])
                body = #"{"success":true,"data":{"userId":42,"accessToken":"access","refreshToken":"refresh","tokenType":"Bearer","expiresIn":1800,"refreshTokenExpiresIn":1209600,"isNewUser":false}}"#
            }
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        try await container.authRepository.loginWithApple()
        #expect(try users.load() == 42)
        #expect(try tokens.load() == AuthToken(accessToken: "access", refreshToken: "refresh"))
    }

    @Test
    func 설정이_없는_번들은_조립에_실패한다() throws {
        let testBundle = Bundle(for: BundleMarker.self)
        #expect(throws: APIConfiguration.ConfigurationError.missingBaseURL) {
            try AppContainer(bundle: testBundle)
        }
    }

    @Test
    func 인증_요청과_인증없는_갱신_요청을_같은_전송으로_조립한다() async throws {
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "old", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        let recorder = AuthRequestRecorder()
        let container = AppContainer(
            configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]),
            tokenStore: tokens, currentUserStore: users
        ) { request in
            await recorder.record(request)
            let body: String
            let status: Int
            if request.url?.path == "/api/v1/auth/token/refresh" {
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                body = #"{"success":true,"data":{"accessToken":"new","refreshToken":"rotated"}}"#
                status = 200
            } else if request.value(forHTTPHeaderField: "Authorization") == "Bearer new" {
                body = #"{"success":true,"data":{"id":7}}"#
                status = 200
            } else {
                body = "{}"
                status = 401
            }
            let url = try #require(request.url)
            return (Data(body.utf8), try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)))
        }
        let item = try await container.apiClient.send(APIRequest(path: ["maps"]), as: Item.self)
        #expect(item.id == 7)
        #expect(await recorder.headers == ["Bearer old", nil, "Bearer new"])
        #expect(try tokens.load() == AuthToken(accessToken: "new", refreshToken: "rotated"))
        #expect(try users.load() == 42)
    }
}

private final class BundleMarker: NSObject {}
