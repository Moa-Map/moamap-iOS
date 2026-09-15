/// 갱신 요청과 결과 저장을 함께 직렬화한다. 대기 중인 요청은 저장 완료 후 재시도한다.
actor AuthSession {
    private let tokenStore: any AuthTokenStore
    private let currentUserStore: any CurrentUserStore
    private let refresher: any TokenRefresher
    private let events: SessionEvents
    private var refreshTask: Task<String?, Error>?

    init(tokenStore: any AuthTokenStore, currentUserStore: any CurrentUserStore, refresher: any TokenRefresher, events: SessionEvents) {
        self.tokenStore = tokenStore
        self.currentUserStore = currentUserStore
        self.refresher = refresher
        self.events = events
    }

    func accessToken() throws -> String? {
        try Task.checkCancellation()
        return try tokenStore.load()?.accessToken
    }

    func refresh(failedAccessToken: String) async throws -> String? {
        try Task.checkCancellation()
        guard let current = try tokenStore.load() else { return nil }
        // 다른 요청이 갱신을 끝낸 뒤 도착한 401에는 새 토큰으로 재시도만 한다.
        if current.accessToken != failedAccessToken { return current.accessToken }

        let task: Task<String?, Error>
        if let refreshTask {
            task = refreshTask
        } else {
            task = Task { try await self.performRefresh(current) }
            refreshTask = task
        }

        // 개별 요청의 취소로 다른 요청들이 기다리는 공유 갱신을 취소하지 않는다.
        do {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    private func performRefresh(_ original: AuthToken) async throws -> String? {
        defer { refreshTask = nil }
        let result = try await refresher.refresh(refreshToken: original.refreshToken)
        try Task.checkCancellation()
        // 갱신을 기다리는 동안 로그아웃/새 로그인이 이루어졌다면 이전 결과를 버린다.
        guard try tokenStore.load() == original else { return nil }
        switch result {
        case .success(let token):
            guard token.isValid else { return nil }
            try tokenStore.save(token)
            return token.accessToken
        case .rejected:
            try expireSession()
            return nil
        case .failed:
            return nil
        }
    }

    private func expireSession() throws {
        // 한 항목의 삭제가 실패해도 나머지 정리와 화면 통지는 수행한다.
        var storageError: (any Error)?
        do { try currentUserStore.clear() } catch { storageError = error }
        do { try tokenStore.clear() } catch { if storageError == nil { storageError = error } }
        events.notifySessionExpired()
        if let storageError { throw storageError }
    }
}
