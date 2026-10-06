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
                MainTabView(
                    exploreViewModel: container.makeExploreViewModel(),
                    collectionViewModel: container.makeCollectionViewModel(),
                    makeSettingsViewModel: container.makeSettingsViewModel,
                    makeProfileEditViewModel: container.makeProfileEditViewModel,
                    makeCreateMapViewModel: container.makeCreateMapViewModel,
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
                loginViewModel.returnToLogin()
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
