import Foundation
import Testing
@testable import MoaMap

struct APIClientTests {
    private func configuration() throws -> APIConfiguration {
        try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/api/"])
    }

    @Test
    func 경로와_쿼리_및_JSON_본문을_구성한다() throws {
        let body = Data(#"{"name":"지도"}"#.utf8)
        let request = APIRequest(
            path: ["maps", "서울 지도"], method: .post,
            queryItems: [URLQueryItem(name: "query", value: "a&b=c")],
            headers: ["Authorization": "Bearer test"], jsonBody: body
        )
        let result = try request.urlRequest(baseURL: configuration().baseURL)
        let url = try #require(result.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api/maps/서울 지도")
        #expect(components.queryItems == request.queryItems)
        #expect(result.httpMethod == "POST")
        #expect(result.httpBody == body)
        #expect(result.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(result.value(forHTTPHeaderField: "Authorization") == "Bearer test")
    }

    @Test(arguments: ["..", ".", "", "maps/other", "https://other.com"])
    func 잘못된_경로_세그먼트를_거부한다(segment: String) throws {
        let baseURL = try configuration().baseURL
        #expect(throws: NetworkError.invalidRequest) {
            try APIRequest(path: [segment]).urlRequest(baseURL: baseURL)
        }
    }

    @Test(arguments: [200, 201, 204, 299])
    func 성공_응답을_반환한다(status: Int) async throws {
        let client = APIClient(configuration: try configuration()) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.httpBody == nil)
            let url = try #require(request.url)
            return (Data("response".utf8), try #require(HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: nil
            )))
        }
        #expect(try await client.send(APIRequest(path: ["maps"])) == Data("response".utf8))
    }

    @Test(arguments: [400, 401, 404, 500])
    func HTTP_오류를_구분한다(status: Int) async throws {
        let client = APIClient(configuration: try configuration()) { request in
            let url = try #require(request.url)
            return (Data(), try #require(HTTPURLResponse(
                url: url, statusCode: status, httpVersion: nil, headerFields: nil
            )))
        }
        await #expect(throws: NetworkError.http(statusCode: status)) {
            try await client.send(APIRequest(path: ["maps"]))
        }
    }

    @Test
    func HTTP가_아닌_응답을_거부한다() async throws {
        let client = APIClient(configuration: try configuration()) { request in
            (Data(), URLResponse(url: try #require(request.url), mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
        }
        await #expect(throws: NetworkError.invalidResponse) {
            try await client.send(APIRequest(path: ["maps"]))
        }
    }

    @Test(arguments: [URLError.Code.timedOut, .notConnectedToInternet])
    func 연결_오류를_구분한다(code: URLError.Code) async throws {
        let client = APIClient(configuration: try configuration()) { _ in throw URLError(code) }
        await #expect(throws: NetworkError.connection(code)) {
            try await client.send(APIRequest(path: ["maps"]))
        }
    }

    @Test(arguments: [true, false])
    func 취소는_연결_오류로_바꾸지_않는다(urlError: Bool) async throws {
        let client = APIClient(configuration: try configuration()) { _ in
            if urlError { throw URLError(.cancelled) }
            throw CancellationError()
        }
        await #expect(throws: CancellationError.self) {
            try await client.send(APIRequest(path: ["maps"]))
        }
    }

    @Test
    func 취소를_무시한_전송이_성공해도_결과를_반환하지_않는다() async throws {
        let client = APIClient(configuration: try configuration()) { request in
            withUnsafeCurrentTask { $0?.cancel() }
            let url = try #require(request.url)
            return (Data(), try #require(HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: nil
            )))
        }
        let task = Task { try await client.send(APIRequest(path: ["maps"])) }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
