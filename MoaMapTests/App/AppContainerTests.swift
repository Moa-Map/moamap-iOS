import Foundation
import Testing
@testable import MoaMap

@MainActor
struct AppContainerTests {
    nonisolated private struct Item: Decodable, Sendable, Equatable { let id: Int }

    @Test
    func 주입한_서버와_전송으로_응답을_처리한다() async throws {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/api/"])
        let container = AppContainer(configuration: configuration) { request in
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
    func 설정이_없는_번들은_조립에_실패한다() throws {
        let testBundle = Bundle(for: BundleMarker.self)
        #expect(throws: APIConfiguration.ConfigurationError.missingBaseURL) {
            try AppContainer(bundle: testBundle)
        }
    }
}

private final class BundleMarker: NSObject {}
