import SwiftUI

private struct TermRoute: Hashable {
    let id: Int64
    let title: String
}

/// 로그인 뒤 홈 앞의 약관 동의. 뒤로 가면 로그아웃하고 로그인 화면으로 돌아간다.
struct TermsAgreementView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @State private var viewModel: TermsAgreementViewModel
    @State private var path: [TermRoute] = []

    private let makeTermDetailViewModel: (Int64) -> TermDetailViewModel
    private let onAgreed: () -> Void
    private let onLoggedOut: () -> Void

    init(
        viewModel: TermsAgreementViewModel,
        makeTermDetailViewModel: @escaping (Int64) -> TermDetailViewModel,
        onAgreed: @escaping () -> Void,
        onLoggedOut: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeTermDetailViewModel = makeTermDetailViewModel
        self.onAgreed = onAgreed
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                MoaMapTopBar(title: "이용약관 동의") { viewModel.leave(onLoggedOut: onLoggedOut) }
                    .disabled(viewModel.uiState.isLeaving)
                switch viewModel.uiState.content {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    MoaMapRetryPrompt(message: message) { viewModel.load(onAgreed: onAgreed) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let pending, let viewOnly):
                    agreement(pending: pending, viewOnly: viewOnly)
                }
            }
            .background { colors.backgroundSecondary.ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TermRoute.self) { route in
                TermDetailView(viewModel: makeTermDetailViewModel(route.id), title: route.title)
            }
        }
        .moaSnackbar(notice)
        .task {
            if viewModel.loadTask == nil { viewModel.load(onAgreed: onAgreed) }
        }
        .preferredColorScheme(.light)
    }

    private func agreement(pending: [Term], viewOnly: [Term]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("서비스 이용약관에\n동의해주세요")
                    .moaTextStyle(typography.title2)
                    .foregroundStyle(colors.textNormal)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 32) {
                    agreeAllRow
                    ForEach(pending) { termRow($0) }
                    ForEach(viewOnly) { viewOnlyRow($0) }
                }
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            submitButton
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.vertical, 12)
        }
    }

    private var agreeAllRow: some View {
        Button { viewModel.toggleAll() } label: {
            HStack(spacing: 8) {
                AgreementCheck(checked: viewModel.uiState.allChecked)
                Text("모두 동의하기")
                    .moaTextStyle(typography.subtitle3)
                    .foregroundStyle(colors.textNormal)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(MoaMapPrimitiveColors.gray50, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(viewModel.uiState.allChecked ? "선택됨" : "선택 안 됨")
    }

    /// 체크 표시와 나머지가 따로 눌린다. 나머지를 누르면 전문을 연다.
    private func termRow(_ term: Term) -> some View {
        let checked = viewModel.uiState.checkedIDs.contains(term.id)
        return HStack(spacing: 8) {
            Button { viewModel.toggle(term) } label: { AgreementCheck(checked: checked) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(term.title) 동의")
                .accessibilityValue(checked ? "선택됨" : "선택 안 됨")
            Button { path.append(TermRoute(id: term.id, title: term.title)) } label: {
                HStack(spacing: 4) {
                    Text(term.title)
                    Text(term.kind == .required ? "(필수)" : "(선택)")
                    Spacer(minLength: 0)
                    Image("Icons/arrow-right").renderingMode(.template).resizable()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
                .moaTextStyle(typography.subtitle4)
                .foregroundStyle(colors.textAlternative)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("전문 보기")
        }
        .padding(.horizontal, 16)
    }

    private func viewOnlyRow(_ term: Term) -> some View {
        Button { path.append(TermRoute(id: term.id, title: term.title)) } label: {
            Text("\(term.title) 보기")
                .moaTextStyle(typography.body2)
                .underline()
                .foregroundStyle(colors.textAlternative)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    /// 필수를 다 체크하기 전에는 누르면 전부 체크하고, 다 체크하면 보낸다.
    private var submitButton: some View {
        let allChecked = viewModel.uiState.allChecked
        return Button {
            if allChecked { viewModel.submit(onAgreed: onAgreed) } else { viewModel.checkAll() }
        } label: {
            ZStack {
                if viewModel.uiState.isSubmitting {
                    ProgressView().tint(colors.textWhite)
                } else {
                    Text(allChecked ? "다음으로" : "모두 동의하기")
                        .moaTextStyle(typography.button0)
                        .foregroundStyle(colors.textWhite)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.uiState.isSubmitting || viewModel.uiState.isLeaving)
    }

    private var notice: Binding<String?> {
        Binding(get: { viewModel.uiState.notice }, set: { if $0 == nil { viewModel.dismissNotice() } })
    }
}

/// 안 고르면 회색, 고르면 파란 체크.
private struct AgreementCheck: View {
    @Environment(\.moaColors) private var colors

    let checked: Bool

    var body: some View {
        Image("Icons/check-thin").renderingMode(.template).resizable()
            .frame(width: 24, height: 24)
            .foregroundStyle(checked ? colors.primary : MoaMapPrimitiveColors.gray100)
            .accessibilityHidden(true)
    }
}
