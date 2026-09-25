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

    init(container: AppContainer) {
        self.container = container
        _loginViewModel = State(initialValue: container.makeLoginViewModel())
    }

    var body: some View {
        ZStack {
            if loginViewModel.uiState == .authenticated {
                MainTabView()
            } else {
                LoginView(
                    loadingProvider: loginViewModel.uiState.loadingProvider,
                    onKakaoLogin: { loginViewModel.loginWithKakao() },
                    onAppleLogin: { loginViewModel.loginWithApple() }
                )
            }
        }
        .task {
            loginViewModel.restoreSession()
            for await _ in container.sessionEvents.sessionExpired {
                guard !Task.isCancelled else { return }
                loginViewModel.sessionExpired()
            }
        }
        .alert("로그인할 수 없습니다", isPresented: showsError) {
            Button("확인", role: .cancel) { loginViewModel.dismissError() }
        } message: {
            if case .failed(let message) = loginViewModel.uiState { Text(message) }
        }
        .onDisappear { loginViewModel.cancelLogin() }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: {
                if case .failed = loginViewModel.uiState { return true }
                return false
            },
            set: { if !$0 { loginViewModel.dismissError() } }
        )
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
