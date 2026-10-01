import Foundation
import Observation

/// 커뮤니티 목록만의 상태. 추천과 닉네임은 독립적으로 갱신한다.
nonisolated enum ExploreUiState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor @Observable
final class ExploreViewModel {
    static let recommendationSize = 10
    /// 앞에서부터 이만큼만 보여 준다. 나머지는 「전체보기」에서 본다.
    static let communityMapCount = 5

    private(set) var uiState: ExploreUiState = .idle
    private(set) var nickname: String?
    private(set) var recommendedMaps: [MapSummary] = []
    private(set) var communityMaps: [MapSummary] = []
    private(set) var sortOrder: MapSortOrder = .popular
    private(set) var loadTask: Task<Void, Never>?
    private(set) var recommendationTask: Task<Void, Never>?
    private(set) var nicknameTask: Task<Void, Never>?

    private let repository: any ExploreRepository

    init(repository: any ExploreRepository) { self.repository = repository }

    /// 처음 화면에 들어올 때만 불러온다. 탭을 오가도 다시 요청하지 않는다.
    func loadIfNeeded() {
        guard uiState == .idle else { return }
        load()
    }

    func load() {
        cancelTasks()
        recommendationTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.recommendationTask = nil } }
            do {
                let maps = try await repository.fetchRecommendedMaps(size: Self.recommendationSize)
                try Task.checkCancellation()
                self?.recommendedMaps = maps
            } catch {
                // 보조 영역은 실패해도 기존 추천을 유지한다. 처음이면 비어 있어 숨겨진다.
            }
        }
        nicknameTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.nicknameTask = nil } }
            do {
                let name = try await repository.fetchMyNickname()
                try Task.checkCancellation()
                self?.nickname = name
            } catch {
                // 이름을 읽지 못하면 화면에서 "회원"을 사용한다.
            }
        }
        retryCommunity()
    }

    /// 정렬 변경과 재시도는 추천·닉네임 요청에 영향을 주지 않는다.
    func retryCommunity() {
        loadTask?.cancel()
        uiState = .loading
        let sort = sortOrder
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let page = try await repository.fetchCommunityMaps(tag: nil, sort: sort, page: 0, size: Self.communityMapCount)
                try Task.checkCancellation()
                self?.communityMaps = page.maps
                self?.uiState = .loaded
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState = .failed(Self.message(for: error))
            }
        }
    }

    func changeSort(_ order: MapSortOrder) {
        guard order != sortOrder else { return }
        sortOrder = order
        if uiState != .idle { retryCommunity() }
    }

    func cancelTasks() {
        recommendationTask?.cancel()
        recommendationTask = nil
        nicknameTask?.cancel()
        nicknameTask = nil
        loadTask?.cancel()
        loadTask = nil
    }

    private static func message(for error: any Error) -> String {
        (error as? NetworkError)?.userMessage ?? "지도를 불러오지 못했어요. 다시 시도해 주세요."
    }
}
