import SwiftUI

struct SettingsView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel
    @State private var logoutDialogVisible = false
    @State private var withdrawDialogVisible = false

    let onOpenTerm: (Term) -> Void
    let onLoggedOut: () -> Void

    init(viewModel: SettingsViewModel, onOpenTerm: @escaping (Term) -> Void, onLoggedOut: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onOpenTerm = onOpenTerm
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 20) {
                    section("알림") {
                        row("알림 on/off") { toggle }
                    }
                    section("정보") {
                        navigationRow("공지사항")
                        navigationRow("이용약관", showsDivider: true) {
                            viewModel.openTerm(code: TermCode.service, onFound: onOpenTerm)
                        }
                        navigationRow("개인정보처리방침", showsDivider: true) {
                            viewModel.openTerm(code: TermCode.policy, onFound: onOpenTerm)
                        }
                        navigationRow("신고하기", showsDivider: true)
                    }
                    section("앱 정보") {
                        row("버전 정보") {
                            Text("v1.0.0")
                                .moaTextStyle(typography.caption2)
                                .foregroundStyle(colors.textAssistive)
                        }
                    }
                    section("계정") {
                        // 바로 로그아웃하지 않고 팝업에서 한 번 더 묻는다. 진행 중이면 다시 묻지 않는다.
                        navigationRow("로그아웃") {
                            if !viewModel.uiState.isBusy { logoutDialogVisible = true }
                        }
                        navigationRow("회원탈퇴", color: colors.statusAlert, showsDivider: true) {
                            if !viewModel.uiState.isBusy { withdrawDialogVisible = true }
                        }
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .overlay {
            if logoutDialogVisible {
                MoaMapConfirmDialog(
                    title: "로그아웃하시겠어요?",
                    message: "다음에 또 지도를 함께 채워요!",
                    dismissText: "닫기",
                    dismissColor: MoaMapPrimitiveColors.gray200,
                    confirmText: "확인",
                    onConfirm: {
                        logoutDialogVisible = false
                        viewModel.logout(onLoggedOut: onLoggedOut)
                    },
                    onDismiss: { logoutDialogVisible = false }
                )
            }
            if withdrawDialogVisible {
                MoaMapConfirmDialog(
                    title: "정말 탈퇴하시겠어요?",
                    message: "만든 지도와 저장한 장소가 모두 삭제되며,\n삭제된 정보는 복구할 수 없어요.",
                    dismissText: "닫기",
                    onConfirm: {
                        withdrawDialogVisible = false
                        viewModel.withdraw(onWithdrawn: onLoggedOut)
                    },
                    onDismiss: { withdrawDialogVisible = false }
                )
            }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { viewModel.cancelTermLoading() }
        .alert(errorTitle, isPresented: showsError) {
            Button("확인", role: .cancel) { viewModel.dismissError() }
        } message: {
            if case .failed(_, let message) = viewModel.uiState { Text(message) }
        }
    }

    private var topBar: some View {
        ZStack {
            Text("설정")
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            Button { dismiss() } label: {
                Image("Icons/arrow-left").renderingMode(.template).resizable()
                    .frame(width: 32, height: 32)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.textNormal)
            .accessibilityLabel("뒤로가기")
            .padding(.leading, MoaMapDimens.screenHorizontalPadding - 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 58)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0, content: content)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4)
        }
    }

    private func row(_ label: String, color: Color? = nil, showsDivider: Bool = false,
                     @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .moaTextStyle(typography.body1)
                .foregroundStyle(color ?? colors.textNormal)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle().fill(colors.lineAlternative).frame(height: 1)
            }
        }
    }

    private func navigationRow(_ label: String, color: Color? = nil, showsDivider: Bool = false,
                               action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            row(label, color: color, showsDivider: showsDivider) {
                Image("Icons/arrow-right").renderingMode(.template).resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(colors.textNormal)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // TODO: 알림 설정 API 가 생기면 상태를 연결한다.
    private var toggle: some View {
        Capsule()
            .fill(MoaMapPrimitiveColors.blue100)
            .frame(width: 48, height: 24)
            .overlay(alignment: .trailing) {
                Circle().fill(colors.primary).frame(width: 18, height: 18).padding(3)
            }
            .accessibilityHidden(true)
    }

    private var errorTitle: String {
        if case .failed(let title, _) = viewModel.uiState { return title }
        return ""
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: {
                if case .failed = viewModel.uiState { return true }
                return false
            },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }
}

#if DEBUG
@MainActor
final class PreviewAuthRepository: AuthRepository {
    func loginWithKakao() async throws {}
    func loginWithApple() async throws {}
    func loginWithGoogle() async throws {}
    func logout() async throws {}
    func withdraw() async throws {}
    func hasSession() throws -> Bool { true }
}

@MainActor
final class PreviewTermsRepository: TermsRepository {
    private static let terms = [
        Term(id: 1, code: TermCode.service, title: "서비스 이용약관", version: "1", kind: .required),
        Term(id: 2, code: "AGE", title: "만 14세 이상 확인", version: "1", kind: .required),
        Term(id: 3, code: TermCode.policy, title: "개인정보 처리방침", version: "1", kind: .viewOnly)
    ]

    func fetchTerms() async throws -> [Term] { Self.terms }
    func fetchTerm(id: Int64) async throws -> TermDetail {
        TermDetail(term: Self.terms[0], isActive: true, content: "# 제1조\n\n**굵게**와 [링크](https://example.com)\n\n1. 하나\n   - 둘")
    }
    func fetchAgreementStatus() async throws -> TermAgreementStatus {
        TermAgreementStatus(needsAgreement: true, pendingTerms: Array(Self.terms.prefix(2)))
    }
    func agree(termIDs: [Int64]) async throws -> TermAgreementStatus {
        TermAgreementStatus(needsAgreement: false, pendingTerms: [])
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(repository: PreviewAuthRepository(), termsRepository: PreviewTermsRepository()),
        onOpenTerm: { _ in }, onLoggedOut: {}
    )
}
#endif
