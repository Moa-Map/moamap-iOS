import Foundation
import Testing
@testable import MoaMap

@MainActor
struct CollectionViewModelTests {
    private func map(_ id: Int64, personal: Bool = false) -> MyMap {
        MyMap(id: id, title: "지도", imageURL: nil, memberCount: 1, placeCount: 0, official: false, personal: personal)
    }

    @Test func 첫_조회와_탭_전환은_필요한_목록만_요청한다() async throws {
        let repository = CollectionRepositoryStub()
        let community = [map(1)]
        repository.fetch = { $0 == .community ? community : [] }
        let sut = CollectionViewModel(repository: repository)
        #expect(repository.calls.isEmpty)
        sut.loadIfNeeded()
        #expect(sut.uiState.currentMaps == .loading)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded(community))
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        sut.selectTab(.community)
        sut.loadIfNeeded()
        #expect(sut.uiState.currentMaps == .loaded(community))
        #expect(repository.calls == [.community, .private])
    }

    @Test func 오류는_서버_원문을_숨기고_현재_탭만_재시도한다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        try await sut.loadTask?.value
        repository.fetch = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .failed("지도 목록을 불러오지 못했어요"))
        #expect(sut.uiState.community == .loaded([]))
        repository.fetch = { _ in [] }
        sut.retry()
        #expect(sut.uiState.currentMaps == .loading)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        #expect(repository.calls == [.community, .private, .private])
    }

    @Test func 새로고침_실패는_기존_목록을_유지하고_다른_탭은_다음에_갱신한다() async throws {
        let repository = CollectionRepositoryStub()
        let maps = [map(1)]
        repository.fetch = { _ in maps }
        let sut = CollectionViewModel(repository: repository)
        sut.selectTab(.private)
        try await sut.loadTask?.value
        sut.selectTab(.community)
        try await sut.loadTask?.value
        repository.fetch = { _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        #expect(sut.uiState.currentMaps == .loaded(maps))
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded(maps))
        repository.fetch = { _ in [] }
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        #expect(repository.calls == [.private, .community, .community, .private])
    }

    @Test(arguments: [false, true])
    func 취소된_이전_요청의_성공과_실패는_최신_상태를_덮지_않는다(fails: Bool) async throws {
        let repository = CollectionRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.fetch = { _ in
            await started.open()
            await release.wait()
            if fails { throw NetworkError.http(statusCode: 500) }
            return []
        }
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        let oldTask = sut.loadTask
        await started.wait()
        let maps = [map(2)]
        repository.fetch = { _ in maps }
        sut.retry()
        try await sut.loadTask?.value
        await release.open()
        await #expect(throws: CancellationError.self) { try await oldTask?.value }
        #expect(sut.uiState.currentMaps == .loaded(maps))
    }

    @Test func 탭을_바꿔도_진행중인_다른_탭_요청은_유지한다() async throws {
        let repository = CollectionRepositoryStub()
        let release = AsyncGate()
        let maps = [map(1)]
        repository.fetch = { type in
            if type == .community { await release.wait(); return maps }
            return []
        }
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        let communityTask = sut.loadTask
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.privateMaps == .loaded([]))
        #expect(sut.uiState.community == .loading)
        await release.open()
        try await communityTask?.value
        #expect(sut.uiState.community == .loaded(maps))
        #expect(sut.uiState.selectedTab == .private)
    }

    @Test func 초대_코드는_영문_대문자와_숫자만_남기고_입력하면_에러를_지운다() {
        let sut = CollectionViewModel(repository: CollectionRepositoryStub())
        sut.updateInviteCode("ab")
        #expect(sut.uiState.join == .hidden)
        sut.openJoinDialog()
        sut.updateInviteCode("#vh-4y 한xz")
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "VH4YXZ")))
    }

    @Test func 빈_코드는_제출하지_않는다() {
        let repository = CollectionRepositoryStub()
        let sut = CollectionViewModel(repository: repository)
        sut.openJoinDialog()
        sut.join()
        #expect(sut.joinTask == nil)
        #expect(repository.joinedCodes.isEmpty)
    }

    @Test func 참여에_성공하면_다이얼로그를_닫고_프라이빗_목록을_다시_읽는다() async throws {
        let repository = CollectionRepositoryStub()
        let joined = [map(5)]
        repository.fetch = { $0 == .private ? joined : [] }
        let sut = CollectionViewModel(repository: repository)
        sut.selectTab(.private)
        try await sut.loadTask?.value
        sut.selectTab(.community)
        try await sut.loadTask?.value
        sut.openJoinDialog()
        sut.updateInviteCode("VH4YXZ")
        sut.join()
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "VH4YXZ", submitting: true)))
        try await sut.joinTask?.value
        #expect(sut.uiState.join == .hidden)
        #expect(sut.uiState.selectedTab == .private)
        try await sut.loadTask?.value
        #expect(sut.uiState.privateMaps == .loaded(joined))
        #expect(repository.joinedCodes == ["VH4YXZ"])
        #expect(repository.calls == [.private, .community, .private])
    }

    @Test(arguments: [
        (NetworkError.server(code: "MAP_007", statusCode: 404), "코드를 다시 확인해주세요"),
        (NetworkError.server(code: "MAP_005", statusCode: 409), "이미 참여 중인 지도예요"),
        (NetworkError.connection(.notConnectedToInternet), "네트워크에 연결할 수 없어요"),
        (NetworkError.server(code: "COMMON_005", statusCode: 500), "지도에 참여하지 못했어요")
    ])
    func 참여_실패는_서버_원문_대신_안내_문구를_보여준다(error: NetworkError, message: String) async throws {
        let repository = CollectionRepositoryStub()
        repository.join = { _ in throw error }
        let sut = CollectionViewModel(repository: repository)
        sut.openJoinDialog()
        sut.updateInviteCode("WRONG1")
        sut.join()
        try await sut.joinTask?.value
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "WRONG1", errorMessage: message)))
        #expect(sut.uiState.selectedTab == .community)
        sut.updateInviteCode("WRONG2")
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "WRONG2")))
    }

    @Test func 요청_중에는_닫기와_입력과_재제출을_막는다() async throws {
        let repository = CollectionRepositoryStub()
        let release = AsyncGate()
        repository.join = { _ in await release.wait() }
        let sut = CollectionViewModel(repository: repository)
        sut.openJoinDialog()
        sut.updateInviteCode("VH4YXZ")
        sut.join()
        let submitting = sut.uiState.join
        sut.closeJoinDialog()
        sut.updateInviteCode("OTHER1")
        sut.join()
        #expect(sut.uiState.join == submitting)
        await release.open()
        try await sut.joinTask?.value
        #expect(repository.joinedCodes == ["VH4YXZ"])
        sut.openJoinDialog()
        sut.closeJoinDialog()
        #expect(sut.uiState.join == .hidden)
    }

    @Test func 개인지도는_전체_목록에_중복되지_않고_순서를_유지한다() {
        let personal = map(1, personal: true)
        let others = [map(2), map(3)]
        let sections = PrivateMapSections(maps: [others[0], personal, others[1]])
        #expect(sections.personal == [personal])
        #expect(sections.others == others)
        #expect(PrivateMapSections(maps: []).personal.isEmpty)
    }
}
