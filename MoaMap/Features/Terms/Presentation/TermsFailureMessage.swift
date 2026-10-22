/// 약관 화면의 실패 안내. 연결 실패만 따로 알린다.
nonisolated enum TermsFailureMessage {
    static let offline = "네트워크에 연결할 수 없어요"

    static func message(for error: any Error, fallback: String) -> String {
        if case .connection = error as? NetworkError { return offline }
        return fallback
    }
}
