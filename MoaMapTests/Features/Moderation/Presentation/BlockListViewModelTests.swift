import Foundation
import Testing
@testable import MoaMap

@MainActor
struct BlockListViewModelTests {
    private let repository = BlockRepositoryStub()
    private let mo = BlockedUser(id: 3, nickname: "모아", profileImageURL: nil)
    private let ah = BlockedUser(id: 4, nickname: "아", profileImageURL: nil)

    private func loaded() async -> (BlockListViewModel, BlockedUserStore) {
        repository.users = { [mo, ah] }
        let store = BlockedUserStore(repository: repository)
        let sut = BlockListViewModel(blockedUsers: store)
        sut.load()
        await sut.loadTask?.value
        return (sut, store)
    }

    @Test func 열면_차단한_사람을_읽는다() async {
        let (sut, store) = await loaded()
        #expect(sut.state == .loaded([mo, ah]))
        #expect(store.ids == [3, 4])
    }

    @Test func 못_읽으면_안내하고_다시_읽을_수_있다() async {
        repository.users = { throw NetworkError.connection(.notConnectedToInternet) }
        let sut = BlockListViewModel(blockedUsers: BlockedUserStore(repository: repository))
        sut.load()
        await sut.loadTask?.value
        #expect(sut.state == .failed("네트워크에 연결할 수 없어요"))
        repository.users = { [] }
        sut.load()
        #expect(sut.state == .loading)
        await sut.loadTask?.value
        #expect(sut.state == .loaded([]))
    }

    @Test func 해제하면_목록과_가릴_사람에서_뺀다() async {
        let (sut, store) = await loaded()
        sut.unblock(userID: 3)
        #expect(sut.unblockingIDs == [3])
        await sut.unblockTasks[3]?.value
        #expect(repository.unblocked == [3])
        #expect(sut.state == .loaded([ah]))
        #expect(store.ids == [4])
        #expect(sut.unblockingIDs.isEmpty)
    }

    @Test func 해제하는_중에는_같은_사람을_다시_보내지_않는다() async {
        let (sut, _) = await loaded()
        sut.unblock(userID: 3)
        sut.unblock(userID: 3)
        await sut.unblockTasks[3]?.value
        #expect(repository.unblocked == [3])
    }

    @Test func 해제하지_못하면_목록을_두고_체크_없이_안내한다() async {
        let (sut, store) = await loaded()
        repository.unblock = { _ in throw NetworkError.http(statusCode: 500) }
        let task = { sut.unblockTasks[3] }
        sut.unblock(userID: 3)
        await task()?.value
        #expect(sut.state == .loaded([mo, ah]))
        #expect(store.ids == [3, 4])
        #expect(sut.toast == .failure("차단을 해제하지 못했어요. 잠시 후 다시 시도해주세요"))
        #expect(sut.unblockingIDs.isEmpty)
    }
}
