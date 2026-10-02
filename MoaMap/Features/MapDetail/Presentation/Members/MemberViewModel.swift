import Foundation
import Observation

nonisolated struct MemberUiState: Equatable, Sendable {
    var loading = true
    var members: [MapMember] = []
    /// 목록을 못 읽었다. 권한 부여 실패와 나눠야 이미 읽어 둔 목록이 사라지지 않는다.
    var errorMessage: String?
    /// 버튼을 연달아 눌러도 서버에는 한 번만 간다.
    var granting = false
    /// 한 번 보여주고 지우는 권한 부여 실패 안내.
    var grantErrorMessage: String?
}

/// 지도 멤버 관리. 화면을 열 때만 필요해 지도 상세 상태에 섞지 않는다.
@MainActor @Observable
final class MemberViewModel {
    let mapID: Int64
    private(set) var uiState = MemberUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var grantTask: Task<Void, Never>?
    private var started = false

    private let repository: any MapMemberRepository

    init(mapID: Int64, repository: any MapMemberRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    /// 화면을 여닫을 때마다 다시 받지 않는다.
    func loadOnce() {
        guard !started else { return }
        started = true
        load()
    }

    func retry() {
        uiState.loading = true
        uiState.errorMessage = nil
        load()
    }

    /// 성공하면 목록을 다시 받지 않고 그 사람의 역할만 바꾼다. 재조회가 실패하면 반영된 권한이 없던 일처럼 보인다.
    func grantAdmin(userID: Int64) {
        guard !uiState.granting else { return }
        uiState.granting = true
        uiState.grantErrorMessage = nil
        grantTask = Task { [weak self, repository, mapID] in
            do {
                try await repository.grantAdmin(mapID: mapID, userID: userID)
                try Task.checkCancellation()
                guard let self else { return }
                self.uiState.granting = false
                if let index = self.uiState.members.firstIndex(where: { $0.id == userID }) {
                    self.uiState.members[index].role = .admin
                }
            } catch {
                guard !(error is CancellationError), let self else { return }
                self.uiState.granting = false
                self.uiState.grantErrorMessage = MapDetailMessage.userMessage(for: error, fallback: MemberMessage.grantFailed)
            }
        }
    }

    func consumeGrantError() {
        uiState.grantErrorMessage = nil
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID] in
            do {
                let members = try await repository.fetchMembers(mapID: mapID)
                try Task.checkCancellation()
                self?.uiState.loading = false
                self?.uiState.members = members
                self?.uiState.errorMessage = nil
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.loading = false
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: MemberMessage.loadFailed)
            }
        }
    }
}

nonisolated enum MemberMessage {
    static let loadFailed = "멤버 목록을 불러오지 못했어요"
    static let grantFailed = "권한을 주지 못했어요"
}

/// 멤버 관리에서 역할을 어디까지 드러낼지. 지도 종류가 정한다.
nonisolated enum MemberRoleDisplay: Sendable {
    /// 커뮤니티: 방장·관리자 태그와 역할 안내.
    case all
    /// 프라이빗: 만든 사람의 방장 태그만. 역할이 나뉘지 않는다.
    case ownerOnly
    /// 공식지도: 역할이 뜻을 갖지 않는다.
    case none

    init(_ type: MapType) {
        self = switch type {
        case .community: .all
        case .private: .ownerOnly
        case .official: .none
        }
    }

    /// 이름 옆에 붙일 태그. 일반 멤버에게는 붙지 않는다.
    func tag(for role: MapRole) -> MapRole? {
        switch role {
        case .owner where self != .none: .owner
        case .admin where self == .all: .admin
        default: nil
        }
    }
}

nonisolated extension MapDetail {
    var memberRoleDisplay: MemberRoleDisplay { MemberRoleDisplay(type) }
    /// 권한 위임은 커뮤니티 지도 방장의 권한이다.
    var canGrantRole: Bool { type == .community && role == .owner }
}
