import SwiftUI

struct SettingsView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SettingsViewModel

    let onLoggedOut: () -> Void

    init(viewModel: SettingsViewModel, onLoggedOut: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
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
                        navigationRow("이용약관", showsDivider: true)
                        navigationRow("개인정보처리방침", showsDivider: true)
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
                        navigationRow("로그아웃", action: viewModel.logout)
                        // TODO: 회원탈퇴 API 가 생기면 연결한다.
                        navigationRow("회원탈퇴", color: colors.statusAlert, showsDivider: true)
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.uiState) { _, state in
            if state == .loggedOut { onLoggedOut() }
        }
        .alert("로그아웃할 수 없습니다", isPresented: showsError) {
            Button("확인", role: .cancel) { viewModel.dismissError() }
        } message: {
            if case .failed(let message) = viewModel.uiState { Text(message) }
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
    func logout() async throws {}
    func hasSession() throws -> Bool { true }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(repository: PreviewAuthRepository()), onLoggedOut: {})
}
#endif
