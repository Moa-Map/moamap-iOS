import AuthenticationServices
import Foundation

@MainActor
final class SystemAppleAuthorizationSession: NSObject, AppleAuthorizationSession,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    private var controller: ASAuthorizationController?
    private var completion: Completion?

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
        super.init()
    }

    func start(nonce: String, completion: @escaping Completion) {
        self.completion = completion
        let controller = ASAuthorizationController(authorizationRequests: [Self.makeRequest(nonce: nonce)])
        self.controller = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func cancel() {
        let pendingController = controller
        finish(.failure(CancellationError()))
        pendingController?.cancel()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(LoginError.invalidResponse))
            return
        }
        finish(Result {
            try Self.credential(identityToken: credential.identityToken,
                                authorizationCode: credential.authorizationCode, fullName: credential.fullName)
        })
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        finish(.failure(Self.loginError(error)))
    }

    private func finish(_ result: Result<AppleLoginCredential, any Error>) {
        let callback = completion
        completion = nil
        controller?.delegate = nil
        controller?.presentationContextProvider = nil
        controller = nil
        callback?(result)
    }

    static func makeRequest(nonce: String) -> ASAuthorizationAppleIDRequest {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
        return request
    }

    static func credential(identityToken: Data?, authorizationCode: Data?, fullName: PersonNameComponents?) throws -> AppleLoginCredential {
        guard let identityToken, let identity = String(data: identityToken, encoding: .utf8), !identity.isEmpty,
              let authorizationCode, let code = String(data: authorizationCode, encoding: .utf8), !code.isEmpty else {
            throw LoginError.invalidResponse
        }
        let name = fullName.map {
            PersonNameComponentsFormatter().string(from: $0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return AppleLoginCredential(identityToken: identity, authorizationCode: code,
                                    fullName: name.flatMap { $0.isEmpty ? nil : $0 })
    }

    static func loginError(_ error: any Error) -> any Error {
        if let appleError = error as? ASAuthorizationError, appleError.code == .canceled {
            return LoginError.cancelled
        }
        return error
    }
}
