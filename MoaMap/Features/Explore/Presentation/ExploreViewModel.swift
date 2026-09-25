import Foundation
import Observation

nonisolated enum ExploreUiState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor @Observable
final class ExploreViewModel {
    static let recommendationSize = 10
    static let pageSize = 20

    private(set) var uiState: ExploreUiState = .idle
    private(set) var nickname: String?
    private(set) var recommendedMaps: [MapSummary] = []
    private(set) var communityMaps: [MapSummary] = []
    private(set) var sortOrder: MapSortOrder = .popular
    private(set) var isLoadingMore = false
    private(set) var loadTask: Task<Void, Never>?
    private(set) var pageTask: Task<Void, Never>?

    private var nextPage = 0
    private var isLastPage = true
    private let repository: any ExploreRepository

    init(repository: any ExploreRepository) { self.repository = repository }

    /// 처음 화면에 들어올 때만 불러온다. 탭을 오가도 다시 요청하지 않는다.
    func loadIfNeeded() {
        guard uiState == .idle else { return }
        load()
    }

    func load() {
        cancelTasks()
        uiState = .loading
        let sort = sortOrder
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            // repository 가 MainActor 에 묶여 있어 async let 대신 같은 actor 의 Task 로 동시에 요청한다.
            // 닉네임은 부가 정보라 실패해도 화면을 막지 않는다.
            let nickname = Task { try? await repository.fetchMyNickname() }
            let recommended = Task { try await repository.fetchRecommendedMaps(size: Self.recommendationSize) }
            let firstPage = Task { try await repository.fetchCommunityMaps(sort: sort, page: 0, size: Self.pageSize) }
            let cancelAll = { @Sendable in
                nickname.cancel()
                recommended.cancel()
                firstPage.cancel()
            }
            do {
                let (maps, page, name) = try await withTaskCancellationHandler {
                    (try await recommended.value, try await firstPage.value, await nickname.value)
                } onCancel: {
                    cancelAll()
                }
                try Task.checkCancellation()
                self?.nickname = name ?? nil
                self?.recommendedMaps = maps
                self?.applyFirstPage(page)
                self?.uiState = .loaded
            } catch {
                cancelAll()
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState = .failed(Self.message(for: error))
            }
        }
    }

    func changeSort(_ order: MapSortOrder) {
        guard order != sortOrder else { return }
        sortOrder = order
        guard uiState == .loaded else {
            if uiState != .idle { load() }
            return
        }
        pageTask?.cancel()
        isLoadingMore = true
        pageTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.pageTask = nil } }
            do {
                let page = try await repository.fetchCommunityMaps(sort: order, page: 0, size: Self.pageSize)
                try Task.checkCancellation()
                self?.applyFirstPage(page)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState = .failed(Self.message(for: error))
            }
            if !Task.isCancelled { self?.isLoadingMore = false }
        }
    }

    /// 목록의 마지막 카드가 보이면 다음 페이지를 이어 붙인다.
    func loadMoreIfNeeded(after map: MapSummary) {
        guard uiState == .loaded, !isLastPage, pageTask == nil,
              map.id == communityMaps.last?.id else { return }
        let sort = sortOrder
        let page = nextPage
        isLoadingMore = true
        pageTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.pageTask = nil } }
            do {
                let result = try await repository.fetchCommunityMaps(sort: sort, page: page, size: Self.pageSize)
                try Task.checkCancellation()
                self?.appendPage(result)
            } catch {
                // 이미 받은 목록은 유지한다. 다음에 마지막 카드가 다시 보이면 재시도한다.
            }
            if !Task.isCancelled { self?.isLoadingMore = false }
        }
    }

    func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        pageTask?.cancel()
        pageTask = nil
        isLoadingMore = false
    }

    private func applyFirstPage(_ page: MapPage) {
        communityMaps = page.maps
        isLastPage = page.isLast
        nextPage = 1
    }

    private func appendPage(_ page: MapPage) {
        let existing = Set(communityMaps.map(\.id))
        communityMaps += page.maps.filter { !existing.contains($0.id) }
        isLastPage = page.isLast
        nextPage += 1
    }

    private static func message(for error: any Error) -> String {
        (error as? NetworkError)?.userMessage ?? "지도를 불러오지 못했어요. 다시 시도해 주세요."
    }
}
