/// Apple 인증 결과. 서버 nonce는 저장소가 요청 단위로 관리한다.
nonisolated struct AppleLoginCredential: Sendable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
}
