//
//  ContentView.swift
//  MoaMap
//
//  Created by jungee on 8/14/26.
//

import SwiftUI

struct ContentView: View {
    let container: AppContainer
    @State private var loginViewModel: LoginViewModel
    @State private var showsLoginSuccess = false

    init(container: AppContainer) {
        self.container = container
        _loginViewModel = State(initialValue: container.makeLoginViewModel())
    }

    var body: some View {
        LoginView(
            isLoading: loginViewModel.uiState == .loading,
            onKakaoLogin: loginAction
        )
        .task {
            loginViewModel.restoreSession()
            for await _ in container.sessionEvents.sessionExpired {
                guard !Task.isCancelled else { return }
                showsLoginSuccess = false
                loginViewModel.sessionExpired()
            }
        }
        .onChange(of: loginViewModel.uiState) { _, state in
            if state == .authenticated { showsLoginSuccess = true }
        }
        .alert(showsLoginSuccess ? "로그인되었습니다" : "로그인할 수 없습니다", isPresented: showsAlert) {
            Button("확인", role: .cancel) { dismissAlert() }
        } message: {
            if case .failed(let message) = loginViewModel.uiState { Text(message) }
        }
        .onDisappear { loginViewModel.cancelLogin() }
    }

    private var loginAction: (() -> Void)? {
        guard loginViewModel.uiState != .authenticated else { return nil }
        return { loginViewModel.loginWithKakao() }
    }

    private var showsAlert: Binding<Bool> {
        Binding(
            get: {
                if case .failed = loginViewModel.uiState { return true }
                return showsLoginSuccess
            },
            set: { if !$0 { dismissAlert() } }
        )
    }

    private func dismissAlert() {
        showsLoginSuccess = false
        loginViewModel.dismissError()
    }
}

#Preview {
    if let configuration = try? APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]) {
        ContentView(container: AppContainer(
            configuration: configuration,
            tokenStore: KeychainAuthTokenStore(service: "com.moamap.preview"),
            currentUserStore: KeychainCurrentUserStore(service: "com.moamap.preview")
        ) { _ in
            throw URLError(.notConnectedToInternet)
        })
    }
}
