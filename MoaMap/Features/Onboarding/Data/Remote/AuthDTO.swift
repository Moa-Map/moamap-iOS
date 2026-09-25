nonisolated struct KakaoLoginRequest: Encodable, Sendable {
    let kakaoAccessToken: String
}

nonisolated struct LoginResponse: Decodable, Sendable {
    let userId: Int64?
    let accessToken: String?
    let refreshToken: String?
}

nonisolated struct AppleNonceResponse: Decodable, Sendable {
    let nonce: String
    let expiresIn: Int
}

nonisolated struct AppleLoginRequest: Encodable, Sendable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    let fullName: String?
}
