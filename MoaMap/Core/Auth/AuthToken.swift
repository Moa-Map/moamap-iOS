/// 만료 정보의 단위와 의미가 확정되지 않아 만료는 401 응답으로 판단한다.
nonisolated struct AuthToken: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String

    var isValid: Bool { !accessToken.isEmpty && !refreshToken.isEmpty }
}
