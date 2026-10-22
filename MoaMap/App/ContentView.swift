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
    @State private var termsGateViewModel: TermsGateViewModel
    @State private var isSplashVisible = true

    /// 로고가 번쩍이고 사라지지 않도록 보장하는 최소 노출 시간. Android 와 같다.
    private static let splashMinimumDuration: Duration = .seconds(1.5)

    init(container: AppContainer) {
        self.container = container
        _loginViewModel = State(initialValue: container.makeLoginViewModel())
        _termsGateViewModel = State(initialValue: container.makeTermsGateViewModel())
    }

    private enum Screen {
        case splash(failureMessage: String?)
        case login(loadingProvider: LoginProvider?, failureMessage: String?)
        case agreement
        case main
    }

    /// 로그인 뒤에는 약관 동의 여부를 확인해야 홈에 들어간다. 확인하는 동안은 들어온 화면에 머문다.
    private var screen: Screen {
        if isSplashVisible { return .splash(failureMessage: nil) }
        guard isAuthenticated else {
            return .login(loadingProvider: loginViewModel.uiState.loadingProvider, failureMessage: nil)
        }
        switch termsGateViewModel.state {
        case .passed:
            return .main
        case .needsAgreement:
            return .agreement
        case .idle, .checking, .unauthorized, .loggingOut, .failed:
            let failure = termsGateViewModel.state.failureMessage
            guard let provider = loginViewModel.loggedInProvider else { return .splash(failureMessage: failure) }
            return .login(loadingProvider: failure == nil ? provider : nil, failureMessage: failure)
        }
    }

    private var isAuthenticated: Bool { loginViewModel.uiState == .authenticated }

    private func logoutFromTermsCheck() {
        termsGateViewModel.logout { loginViewModel.returnToLogin() }
    }

    var body: some View {
        ZStack {
            switch screen {
            case .splash(let failureMessage):
                SplashView(
                    failureMessage: failureMessage,
                    onRetry: { termsGateViewModel.check() },
                    onLogout: logoutFromTermsCheck
                )
            case .agreement:
                TermsAgreementView(
                    viewModel: container.makeTermsAgreementViewModel(),
                    makeTermDetailViewModel: container.makeTermDetailViewModel(termID:),
                    onAgreed: { termsGateViewModel.agreed() },
                    onLoggedOut: { loginViewModel.returnToLogin() }
                )
            case .main:
                MainTabView(
                    exploreViewModel: container.makeExploreViewModel(),
                    collectionViewModel: container.makeCollectionViewModel(),
                    makeSettingsViewModel: container.makeSettingsViewModel,
                    makeTermDetailViewModel: container.makeTermDetailViewModel(termID:),
                    makeProfileEditViewModel: container.makeProfileEditViewModel,
                    makeCreateMapViewModel: container.makeCreateMapViewModel,
                    makeEditMapViewModel: container.makeEditMapViewModel(map:),
                    makePlaceImportViewModel: container.makePlaceImportViewModel(source:url:),
                    makeCommunityMapListViewModel: container.makeCommunityMapListViewModel,
                    makeOfficialMapListViewModel: container.makeOfficialMapListViewModel,
                    makeDensityMapViewModel: container.makeDensityMapViewModel,
                    makeRestroomMapViewModel: container.makeRestroomMapViewModel,
                    makeMapIntroViewModel: container.makeMapIntroViewModel(mapID:),
                    makeMapDetailViewModels: container.makeMapDetailViewModels(mapID:),
                    makeMapMembershipViewModel: container.makeMapMembershipViewModel(mapID:),
                    sharedLinkInbox: container.sharedLinkInbox,
                    locationProvider: container.locationProvider,
                    onLoggedOut: { loginViewModel.returnToLogin() }
                )
            case .login(let loadingProvider, let failureMessage):
                LoginView(
                    loadingProvider: loadingProvider,
                    onKakaoLogin: { loginViewModel.loginWithKakao() },
                    onAppleLogin: { loginViewModel.loginWithApple() },
                    onGoogleLogin: { loginViewModel.loginWithGoogle() },
                    failureMessage: failureMessage,
                    onRetry: { termsGateViewModel.check() },
                    onLogout: logoutFromTermsCheck
                )
            }
        }
        .onChange(of: isAuthenticated, initial: true) { _, authenticated in
            if authenticated { termsGateViewModel.check() } else { termsGateViewModel.reset() }
        }
        .onChange(of: termsGateViewModel.state) { _, state in
            if state == .unauthorized { loginViewModel.returnToLogin() }
        }
        .task {
            loginViewModel.restoreSession()
            for await _ in container.sessionEvents.sessionExpired {
                guard !Task.isCancelled else { return }
                loginViewModel.returnToLogin()
            }
        }
        .task {
            try? await Task.sleep(for: Self.splashMinimumDuration)
            isSplashVisible = false
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
                // 스플래시 위에 오류가 먼저 뜨지 않도록 로그인 화면이 보인 뒤에 띄운다.
                if isSplashVisible { return false }
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
            currentUserStore: KeychainCurrentUserStore(service: "com.moamap.preview"),
            loginProviderStore: KeychainLoginProviderStore(service: "com.moamap.preview")
        ) { _ in
            throw URLError(.notConnectedToInternet)
        })
    }
}
