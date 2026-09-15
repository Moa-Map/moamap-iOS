nonisolated struct KakaoLoginRequest: Encodable, Sendable {
    let kakaoAccessToken: String
}

nonisolated struct KakaoLoginResponse: Decodable, Sendable {
    let userId: Int64?
    let accessToken: String?
    let refreshToken: String?
}
