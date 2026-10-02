import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MemberViewModelTests {
    @Test func 처음_열_때_한_번만_읽는다() async {
        let repository = MapMemberRepositoryStub()
        repository.members = { _ in [.fixture(id: 1, role: .owner), .fixture(id: 2)] }
        let sut = MemberViewModel(mapID: 7, repository: repository)
        #expect(sut.uiState.loading)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadOnce()
        #expect(repository.fetchCalls == 1)
        #expect(!sut.uiState.loading)
        #expect(sut.uiState.members.map(\.id) == [1, 2])
    }

    @Test func 목록을_못_읽으면_다시_시도할_수_있다() async {
        let repository = MapMemberRepositoryStub()
        repository.members = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = MemberViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(sut.uiState.errorMessage == "멤버 목록을 불러오지 못했어요")
        repository.members = { _ in [.fixture(id: 1)] }
        sut.retry()
        #expect(sut.uiState.loading)
        await sut.loadTask?.value
        #expect(sut.uiState.errorMessage == nil)
        #expect(sut.uiState.members.count == 1)
    }

    @Test func 권한을_주면_다시_읽지_않고_그_사람만_관리자로_바꾼다() async {
        let repository = MapMemberRepositoryStub()
        repository.members = { _ in [.fixture(id: 1, role: .owner), .fixture(id: 2)] }
        let sut = MemberViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.grantAdmin(userID: 2)
        #expect(sut.uiState.granting)
        await sut.grantTask?.value
        #expect(!sut.uiState.granting)
        #expect(sut.uiState.members.map(\.role) == [.owner, .admin])
        #expect(repository.fetchCalls == 1)
    }

    @Test func 권한_부여가_도는_동안_다시_눌러도_한_번만_보낸다() async {
        let repository = MapMemberRepositoryStub()
        let release = AsyncGate()
        repository.grant = { _ in await release.wait() }
        let sut = MemberViewModel(mapID: 7, repository: repository)
        sut.grantAdmin(userID: 2)
        sut.grantAdmin(userID: 3)
        await release.open()
        await sut.grantTask?.value
        #expect(repository.grantCalls == 1)
    }

    @Test func 권한_부여에_실패해도_목록은_남기고_안내만_한다() async {
        let repository = MapMemberRepositoryStub()
        repository.members = { _ in [.fixture(id: 2)] }
        repository.grant = { _ in throw NetworkError.server(code: "MAP_003", statusCode: 403) }
        let sut = MemberViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.grantAdmin(userID: 2)
        await sut.grantTask?.value
        #expect(sut.uiState.members == [.fixture(id: 2)])
        #expect(sut.uiState.errorMessage == nil)
        #expect(sut.uiState.grantErrorMessage == "권한을 주지 못했어요")
        sut.consumeGrantError()
        #expect(sut.uiState.grantErrorMessage == nil)
    }

    @Test func 역할_태그는_지도_종류에_따라_드러낸다() {
        #expect(MemberRoleDisplay.all.tag(for: .owner) == .owner)
        #expect(MemberRoleDisplay.all.tag(for: .admin) == .admin)
        #expect(MemberRoleDisplay.all.tag(for: .member) == nil)
        #expect(MemberRoleDisplay.ownerOnly.tag(for: .owner) == .owner)
        #expect(MemberRoleDisplay.ownerOnly.tag(for: .admin) == nil)
        #expect(MemberRoleDisplay.none.tag(for: .owner) == nil)
        #expect(MemberRoleDisplay(.private) == .ownerOnly)
    }

    @Test func 권한_위임은_커뮤니티_지도_방장만_한다() {
        #expect(MapDetail.fixture(joined: true, type: .community, role: .owner).canGrantRole)
        #expect(!MapDetail.fixture(joined: true, type: .community, role: .admin).canGrantRole)
        #expect(!MapDetail.fixture(joined: true, type: .private, role: .owner).canGrantRole)
    }
}
