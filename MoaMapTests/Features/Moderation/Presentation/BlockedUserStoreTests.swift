import Foundation
import Testing
@testable import MoaMap

@MainActor
struct BlockedUserStoreTests {
    private let repository = BlockRepositoryStub()

    @Test func 서버_목록으로_맞추고_그_목록을_돌려준다() async throws {
        repository.users = { [BlockedUser(id: 3, nickname: "모아", profileImageURL: nil)] }
        let sut = BlockedUserStore(repository: repository)
        let users = try await sut.reload()
        #expect(users.map(\.id) == [3])
        #expect(sut.ids == [3])
    }

    @Test func 차단하면_넣고_해제하면_뺀다() async throws {
        let sut = BlockedUserStore(repository: repository)
        try await sut.block(userID: 3)
        try await sut.block(userID: 4)
        try await sut.unblock(userID: 3)
        #expect(sut.ids == [4])
        #expect(repository.blocked == [3, 4])
        #expect(repository.unblocked == [3])
    }

    @Test func 서버가_거절하면_바꾸지_않는다() async {
        repository.block = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = BlockedUserStore(repository: repository)
        await #expect(throws: NetworkError.http(statusCode: 500)) { try await sut.block(userID: 3) }
        #expect(sut.ids.isEmpty)
    }

    @Test func 비운_뒤에_늦게_온_목록은_반영하지_않는다() async throws {
        let (gate, open) = AsyncStream<Void>.makeStream()
        repository.users = {
            for await _ in gate { break }
            return [BlockedUser(id: 3, nickname: nil, profileImageURL: nil)]
        }
        let sut = BlockedUserStore(repository: repository)
        let loading = Task { try await sut.reload() }
        await Task.yield()
        sut.clear()
        open.yield()
        _ = try await loading.value
        #expect(sut.ids.isEmpty)
    }
}
