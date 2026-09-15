import Foundation
import Testing
@testable import MoaMap

struct KeychainAuthStoreTests {
    @Test
    func 저장소를_재생성해도_토큰과_신원을_읽고_독립적으로_삭제한다() throws {
        let service = "MoaMapTests.auth.\(UUID().uuidString)"
        let tokens = KeychainAuthTokenStore(service: service)
        let users = KeychainCurrentUserStore(service: service)
        defer { try? tokens.clear(); try? users.clear() }
        #expect(try tokens.load() == nil)
        try tokens.save(AuthToken(accessToken: "old", refreshToken: "refresh"))
        try users.save(userId: 42)
        try tokens.save(AuthToken(accessToken: "new", refreshToken: "rotated"))
        #expect(try KeychainAuthTokenStore(service: service).load() == AuthToken(accessToken: "new", refreshToken: "rotated"))
        #expect(try KeychainCurrentUserStore(service: service).load() == 42)
        try tokens.clear()
        try tokens.clear()
        #expect(try tokens.load() == nil)
        #expect(try users.load() == 42)
        try users.clear()
        #expect(try users.load() == nil)
    }

    @Test
    func 불완전한_토큰과_유효하지_않은_신원은_세션으로_읽지_않는다() throws {
        let service = "MoaMapTests.auth.\(UUID().uuidString)"
        let tokens = KeychainAuthTokenStore(service: service)
        let users = KeychainCurrentUserStore(service: service)
        defer { try? tokens.clear(); try? users.clear() }
        try tokens.save(AuthToken(accessToken: "", refreshToken: "refresh"))
        #expect(try tokens.load() == nil)
        try tokens.save(AuthToken(accessToken: "access", refreshToken: ""))
        #expect(try tokens.load() == nil)
        try users.save(userId: 0)
        #expect(try users.load() == nil)
        try users.save(userId: 42)
        try users.save(userId: -1)
        #expect(try users.load() == 42)
    }
}
