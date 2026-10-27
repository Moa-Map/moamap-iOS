import SwiftUI

/// 설정 「차단 관리」. 차단한 사람이 없으면 안내를 화면 전체의 가운데에 둔다.
struct BlockListView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: BlockListViewModel

    init(viewModel: BlockListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "차단 관리") { dismiss() }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if case .loaded(let users) = viewModel.state, users.isEmpty { empty }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .moaToast(Binding(get: { viewModel.toast }, set: { if $0 == nil { viewModel.consumeToast() } }), bottomInset: 20)
        .task { if viewModel.loadTask == nil { viewModel.load() } }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            MoaMapRetryPrompt(message: message) { viewModel.load() }
        case .loaded(let users) where users.isEmpty:
            Color.clear
        case .loaded(let users):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    LazyVStack(spacing: 4) {
                        ForEach(users) { user in
                            BlockedUserRow(user: user, unblocking: viewModel.unblockingIDs.contains(user.id)) {
                                viewModel.unblock(userID: user.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("차단한 사용자")
                .moaTextStyle(typography.subtitle1)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 4) {
                Image("Icons/info").renderingMode(.template).resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("차단한 사용자의 댓글과 게시물은 보이지 않아요")
                    .moaTextStyle(typography.body2)
            }
            .foregroundStyle(colors.textAssistive)
        }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Image("moa-symbol-large")
                .resizable()
                // 에셋에 그림자 여백이 들어 있어 본체(75×62.6)보다 크게 그리고 자리는 본체만큼 잡는다.
                .frame(width: 83.125, height: 70.75)
                .frame(width: 75, height: 62.627)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("차단한 사용자가 없어요")
                    .moaTextStyle(typography.subtitle4)
                    .foregroundStyle(colors.textAlternative)
                Text("차단한 사용자는 여기에 표시돼요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
    }
}

private struct BlockedUserRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let user: BlockedUser
    let unblocking: Bool
    let onUnblock: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 12) {
                RemoteImage(url: user.profileImageURL)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(colors.lineAlternative, lineWidth: 1) }
                    .accessibilityHidden(true)
                Text(user.nickname ?? "알 수 없는 사용자")
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(action: onUnblock) {
                Text("차단 해제")
                    .moaTextStyle(typography.button2)
                    .foregroundStyle(colors.textWhite)
                    .padding(8)
                    .background(MoaMapPrimitiveColors.gray200, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(unblocking)
            .accessibilityLabel("\(user.nickname ?? "알 수 없는 사용자") 차단 해제")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 2)
    }
}
