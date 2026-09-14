import Foundation
import Testing
@testable import MoaMap

struct APIResponseTests {
    nonisolated private struct Item: Decodable, Sendable, Equatable { let id: Int }

    nonisolated private struct ThrowsCancellation: Decodable, Sendable {
        init(from decoder: any Decoder) throws { throw CancellationError() }
    }

    nonisolated private struct CancelsThenFails: Decodable, Sendable {
        init(from decoder: any Decoder) throws {
            withUnsafeCurrentTask { $0?.cancel() }
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "fixture"))
        }
    }

    private func client(_ body: String, status: Int = 200) throws -> APIClient {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])
        return APIClient(configuration: configuration) { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
    }

    @Test
    func 성공_데이터와_알_수_없는_필드를_처리한다() async throws {
        let api = try client(#"{"success":true,"data":{"id":1,"extra":"ignored"},"error":null}"#)
        #expect(try await api.send(APIRequest(path: []), as: Item.self) == Item(id: 1))
    }

    @Test(arguments: [#"{"success":true}"#, #"{"success":true,"data":null}"#])
    func 필요한_데이터가_없으면_오류다(body: String) async throws {
        let api = try client(body)
        await #expect(throws: NetworkError.emptyData) {
            try await api.send(APIRequest(path: []), as: Item.self)
        }
    }

    @Test(arguments: ["not json", #"{"success":true,"data":{"id":"wrong"}}"#])
    func 디코딩_실패를_구분한다(body: String) async throws {
        let api = try client(body)
        await #expect(throws: NetworkError.decoding) {
            try await api.send(APIRequest(path: []), as: Item.self)
        }
    }

    @Test(arguments: [200, 500])
    func 실패_응답은_데이터보다_서버_코드를_우선한다(status: Int) async throws {
        let api = try client(#"{"success":false,"data":"wrong shape","error":{"code":"COMMON_005","status":503,"message":"internal secret"}}"#, status: status)
        await #expect(throws: NetworkError.server(code: "COMMON_005", statusCode: 503)) {
            try await api.send(APIRequest(path: []), as: Item.self)
        }
        #expect(!NetworkError.server(code: "COMMON_005", statusCode: 503).userMessage.contains("COMMON_005"))
    }

    @Test
    func 서버_오류_필드의_기본값을_적용한다() async throws {
        let api = try client(#"{"error":{"status":0}}"#, status: 401)
        await #expect(throws: NetworkError.server(code: "UNKNOWN", statusCode: 401)) {
            try await api.sendWithoutResponse(APIRequest(path: []))
        }
    }

    @Test(arguments: [#"{"success":false}"#, "{}"])
    func 성공_표시가_없으면_실패다(body: String) async throws {
        let api = try client(body)
        await #expect(throws: NetworkError.server(code: "UNKNOWN", statusCode: 200)) {
            try await api.sendWithoutResponse(APIRequest(path: []))
        }
    }

    @Test(arguments: ["", #"{"success":true}"#, #"{"success":true,"data":null}"#])
    func 반환_데이터가_필요없는_요청을_처리한다(body: String) async throws {
        try await client(body, status: body.isEmpty ? 204 : 200)
            .sendWithoutResponse(APIRequest(path: []))
    }

    @Test
    func JSON이_아닌_HTTP_오류도_보존한다() async throws {
        let api = try client("<html>Bad Gateway</html>", status: 502)
        await #expect(throws: NetworkError.http(statusCode: 502)) {
            try await api.sendWithoutResponse(APIRequest(path: []))
        }
    }

    @Test(arguments: [201, 202, 206], [
        #"{"success":false}"#,
        #"{"success":false,"error":{"status":0}}"#,
        #"{"success":false,"error":{}}"#,
    ])
    func 실제_HTTP_상태를_실패_응답에_보존한다(status: Int, body: String) async throws {
        let api = try client(body, status: status)
        await #expect(throws: NetworkError.server(code: "UNKNOWN", statusCode: status)) {
            try await api.send(APIRequest(path: []), as: Item.self)
        }
        await #expect(throws: NetworkError.server(code: "UNKNOWN", statusCode: status)) {
            try await api.sendWithoutResponse(APIRequest(path: []))
        }
    }

    @Test
    func 디코더가_던진_취소를_전파한다() async throws {
        let api = try client(#"{"success":true,"data":{}}"#)
        await #expect(throws: CancellationError.self) {
            try await api.send(APIRequest(path: []), as: ThrowsCancellation.self)
        }
    }

    @Test
    func 디코딩_실패_도중_취소되면_취소를_우선한다() async throws {
        let api = try client(#"{"success":true,"data":{}}"#)
        // 테스트 자체가 아니라 자식 작업만 취소한다.
        let task = Task { try await api.send(APIRequest(path: []), as: CancelsThenFails.self) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
