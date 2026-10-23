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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: CollectionRepositoryStub(), mapRepository: MapDetailRepositoryStub())
        sut.updateInviteCode("ab")
        #expect(sut.uiState.join == .hidden)
        sut.openJoinDialog()
        sut.updateInviteCode("#vh-4y 한xz")
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "VH4YXZ")))
    }

    @Test func 여섯_자리가_안_된_코드는_제출하지_않는다() {
        let repository = CollectionRepositoryStub()
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
        sut.openJoinDialog()
        sut.join()
        sut.updateInviteCode("VH4YX")
        sut.join()
        #expect(sut.joinTask == nil)
        #expect(repository.joinedCodes.isEmpty)
    }

    @Test func 초대_코드는_여섯_자리까지만_받는다() {
        let sut = CollectionViewModel(repository: CollectionRepositoryStub(), mapRepository: MapDetailRepositoryStub())
        sut.openJoinDialog()
        sut.updateInviteCode("VH4YXZ7")
        #expect(sut.uiState.join == .editing(JoinMapEditing(code: "VH4YXZ")))
    }

    @Test func 참여에_성공하면_다이얼로그를_닫고_프라이빗_목록을_다시_읽는다() async throws {
        let repository = CollectionRepositoryStub()
        let joined = [map(5)]
        repository.fetch = { $0 == .private ? joined : [] }
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
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

    private func editing(
        _ repository: CollectionRepositoryStub = CollectionRepositoryStub(),
        mapRepository: MapDetailRepositoryStub,
        selecting ids: [Int64]
    ) async throws -> CollectionViewModel {
        let sut = CollectionViewModel(repository: repository, mapRepository: mapRepository)
        sut.loadIfNeeded()
        try await sut.loadTask?.value
        sut.startEditing()
        ids.forEach { sut.toggleSelection(mapID: $0) }
        return sut
    }

    @Test func 편집은_지도를_골랐다_풀고_탭을_바꾸면_끝난다() async throws {
        let sut = try await editing(mapRepository: MapDetailRepositoryStub(), selecting: [1, 2])
        #expect(sut.uiState.editing?.selectedIDs == [1, 2])
        #expect(sut.uiState.editing?.canLeave == true)
        #expect(sut.uiState.editing?.canEditInfo == false)
        sut.toggleSelection(mapID: 2)
        #expect(sut.uiState.editing?.selectedIDs == [1])
        #expect(sut.uiState.editing?.canEditInfo == true)
        sut.selectTab(.private)
        #expect(sut.uiState.editing == nil)
    }

    @Test func 방장인_지도가_섞이면_나가지_않고_막는다() async throws {
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, role: $0 == 2 ? .owner : .member) }
        let sut = try await editing(mapRepository: mapRepository, selecting: [1, 2])
        sut.requestLeave()
        #expect(sut.uiState.editing?.processing == true)
        await sut.editTask?.value
        #expect(sut.uiState.editDialog == .ownerCannotLeave)
        #expect(sut.uiState.editing?.processing == false)
        sut.confirmLeave()
        #expect(mapRepository.leaveCalls == 0)
    }

    @Test(arguments: [(MapType.community, LeaveOutcome.leave), (.private, .leaveNeedsInviteCode)])
    func 확인하면_고른_지도에서_모두_나가고_목록을_다시_읽는다(type: MapType, outcome: LeaveOutcome) async throws {
        let repository = CollectionRepositoryStub()
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, type: type, role: .member) }
        var left: [Int64] = []
        mapRepository.leave = { left.append($0) }
        let sut = try await editing(repository, mapRepository: mapRepository, selecting: [3, 1])
        sut.requestLeave()
        await sut.editTask?.value
        #expect(sut.uiState.editDialog == .confirmLeave(count: 2, outcome: outcome))
        sut.confirmLeave()
        #expect(sut.uiState.editDialog == nil)
        await sut.editTask?.value
        #expect(left == [1, 3])
        #expect(sut.uiState.editing == nil)
        try await sut.loadTask?.value
        #expect(repository.calls == [.community, .community])
    }

    @Test func 일부만_나가지_못하면_실패한_지도만_남기고_안내한다() async throws {
        let repository = CollectionRepositoryStub()
        // 나가지 못한 지도는 다시 읽은 목록에도 남아 있다.
        repository.fetch = { _ in [self.map(2)] }
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        mapRepository.leave = { if $0 == 2 { throw NetworkError.http(statusCode: 500) } }
        let sut = try await editing(repository, mapRepository: mapRepository, selecting: [1, 2])
        sut.requestLeave()
        await sut.editTask?.value
        sut.confirmLeave()
        await sut.editTask?.value
        #expect(sut.uiState.editing?.selectedIDs == [2])
        #expect(sut.uiState.notice == MapDetailMessage.leaveFailed)
        try await sut.loadTask?.value
        #expect(repository.calls == [.community, .community])
    }

    @Test func 역할을_확인하지_못하면_안내하고_편집은_남긴다() async throws {
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = try await editing(mapRepository: mapRepository, selecting: [1])
        sut.requestLeave()
        await sut.editTask?.value
        #expect(sut.uiState.editDialog == nil)
        #expect(sut.uiState.notice == "네트워크에 연결할 수 없어요")
        #expect(sut.uiState.editing == CollectionEditing(selectedIDs: [1]))
    }

    @Test(arguments: [MapRole.owner, .admin, .member])
    func 정보_수정은_방장과_관리자에게만_연다(role: MapRole) async throws {
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, role: role) }
        let sut = try await editing(mapRepository: mapRepository, selecting: [4])
        sut.requestEditInfo()
        await sut.editTask?.value
        if role == .member {
            #expect(sut.uiState.mapToEdit == nil)
            #expect(sut.uiState.notice == EditMapViewModel.noPermissionMessage)
        } else {
            #expect(sut.uiState.mapToEdit?.id == 4)
            sut.consumeMapToEdit()
            #expect(sut.uiState.mapToEdit == nil)
        }
    }

    @Test func 정보를_고치면_편집을_끝내고_목록을_다시_읽는다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = try await editing(repository, mapRepository: MapDetailRepositoryStub(), selecting: [1])
        sut.mapEdited()
        #expect(sut.uiState.editing == nil)
        try await sut.loadTask?.value
        #expect(repository.calls == [.community, .community])
    }

    @Test func 편집_중_목록이_비면_편집을_끝낸다() async throws {
        let repository = CollectionRepositoryStub()
        repository.fetch = { _ in [self.map(1)] }
        let sut = try await editing(repository, mapRepository: MapDetailRepositoryStub(), selecting: [1])
        repository.fetch = { _ in [] }
        sut.refresh()
        try await sut.loadTask?.value
        #expect(sut.uiState.editing == nil)
    }

    @Test func 혼자_남은_프라이빗_방장도_여러_개_나가기에서는_막는다() async throws {
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, type: .private, role: .owner) }
        let sut = try await editing(mapRepository: mapRepository, selecting: [1])
        sut.requestLeave()
        await sut.editTask?.value
        #expect(sut.uiState.editDialog == .ownerCannotLeave)
    }

    @Test func 끌어서_옮겨도_완료할_때_탭의_전체_순서를_한_번만_보낸다() async throws {
        let repository = CollectionRepositoryStub()
        repository.fetch = { _ in [self.map(1), self.map(2), self.map(3)] }
        let sut = try await editing(repository, mapRepository: MapDetailRepositoryStub(), selecting: [])
        sut.moveMap(3, to: 2)
        sut.moveMap(3, to: 1)
        #expect(sut.uiState.currentMaps == .loaded([map(3), map(1), map(2)]))
        #expect(repository.orders.isEmpty)
        sut.finishEditing()
        await sut.orderTask?.value
        #expect(repository.orders.map(\.mapIDs) == [[3, 1, 2]])
        #expect(repository.orders.map(\.type) == [.community])
        sut.startEditing()
        sut.finishEditing()
        #expect(repository.orders.count == 1)
    }

    @Test func 순서를_바꾸고_나가면_순서를_먼저_저장한_뒤_나간다() async throws {
        let repository = CollectionRepositoryStub()
        repository.fetch = { _ in [self.map(1), self.map(2)] }
        let mapRepository = MapDetailRepositoryStub()
        mapRepository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        var events: [String] = []
        repository.updateOrder = { _, ids in events.append("order \(ids)") }
        mapRepository.leave = { events.append("leave \($0)") }
        let sut = try await editing(repository, mapRepository: mapRepository, selecting: [])
        sut.moveMap(2, to: 1)
        sut.toggleSelection(mapID: 1)
        sut.requestLeave()
        await sut.editTask?.value
        sut.confirmLeave()
        await sut.editTask?.value
        #expect(events == ["order [2, 1]", "leave 1"])
    }

    @Test func 편집이_아니거나_나만의_지도와_섞이면_옮기지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        let maps = [map(1, personal: true), map(2), map(3)]
        repository.fetch = { _ in maps }
        let sut = CollectionViewModel(repository: repository, mapRepository: MapDetailRepositoryStub())
        sut.selectTab(.private)
        try await sut.loadTask?.value
        sut.moveMap(3, to: 2)
        #expect(sut.uiState.currentMaps == .loaded(maps))
        sut.startEditing()
        sut.moveMap(3, to: 1)
        #expect(sut.uiState.currentMaps == .loaded(maps))
        sut.moveMap(3, to: 2)
        #expect(sut.uiState.currentMaps == .loaded([map(1, personal: true), map(3), map(2)]))
    }

    @Test func 끝낼_때_저장하지_않은_순서를_보내고_실패하면_서버_순서로_되돌린다() async throws {
        let repository = CollectionRepositoryStub()
        let maps = [map(1), map(2)]
        repository.fetch = { _ in maps }
        repository.updateOrder = { _, _ in throw NetworkError.server(code: "MAP_022", statusCode: 400) }
        let sut = try await editing(repository, mapRepository: MapDetailRepositoryStub(), selecting: [])
        sut.moveMap(2, to: 1)
        sut.finishEditing()
        #expect(sut.uiState.editing == nil)
        await sut.orderTask?.value
        #expect(repository.orders.map(\.mapIDs) == [[2, 1]])
        #expect(sut.uiState.notice == CollectionViewModel.orderFailedMessage)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded(maps))
    }
}
