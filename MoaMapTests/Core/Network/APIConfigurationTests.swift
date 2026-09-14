import Foundation
import Testing
@testable import MoaMap

struct APIConfigurationTests {
    @Test(arguments: [
        "https://example.com/",
        "http://127.0.0.1:8080/",
        "https://example.com/api/v1/",
    ])
    func 서버_주소와_경로를_보존한다(value: String) throws {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": value])
        #expect(configuration.baseURL.absoluteString == value)
    }

    @Test
    func 주소_앞뒤_공백을_제거한다() throws {
        let configuration = try APIConfiguration(infoDictionary: ["BASE_URL": " \nhttps://example.com/ \n"])
        #expect(configuration.baseURL.absoluteString == "https://example.com/")
    }

    @Test
    func 누락된_주소를_구분한다() {
        #expect(throws: APIConfiguration.ConfigurationError.missingBaseURL) {
            try APIConfiguration(infoDictionary: [:])
        }
    }

    @Test(arguments: ["", " \n"])
    func 빈_주소는_누락으로_처리한다(value: String) {
        #expect(throws: APIConfiguration.ConfigurationError.missingBaseURL) {
            try APIConfiguration(infoDictionary: ["BASE_URL": value])
        }
    }

    @Test(arguments: [
        "$(BASE_URL)", "https://$(API_HOST)/", "example.com", "/api/",
        "https://", "http:", "file:///tmp/api", "ftp://example.com/",
        "https://exam ple.com/", "https://example.com/a b",
        "https://user:password@example.com/", "https://example.com/?key=value",
        "https://example.com/#fragment", "https://example.com:65536/",
    ])
    func 잘못된_주소를_거부한다(value: String) {
        #expect(throws: APIConfiguration.ConfigurationError.invalidBaseURL) {
            try APIConfiguration(infoDictionary: ["BASE_URL": value])
        }
    }

    @Test
    func 문자열이_아닌_설정값을_거부한다() {
        #expect(throws: APIConfiguration.ConfigurationError.invalidBaseURL) {
            try APIConfiguration(infoDictionary: ["BASE_URL": 123])
        }
    }
}
