import SwiftUI

/// 장소 대신 전용 지도를 보여 주는 공식지도(유동인구·공중화장실)의 틀. 상단바 아래에 `content` 를 둔다.
///
/// 참여·나가기는 지도 상세와 같다. 같은 지도 번호로 지도 상세의 `MapDetailViewModel` 을 그대로 쓰고,
/// 상단바·나가기 팝업도 지도 상세 것을 쓴다. 공식지도는 메뉴 없이 참여하기/나가기 글자다.
struct OfficialMapScaffold<Content: View>: View {
    @Environment(\.moaColors) private var colors

    @State private var membership: MapDetailViewModel
    /// 서버 이름이 오기 전까지 상단바를 채운다.
    private let initialTitle: String
    /// 이 화면에서 참여했는지를 함께 넘긴다. 어디까지 되돌릴지는 내비게이션이 정한다.
    private let onBack: (_ joinedHere: Bool) -> Void
    private let content: Content

    @State private var leaveDialogVisible = false

    init(
        membership: MapDetailViewModel,
        initialTitle: String,
        onBack: @escaping (_ joinedHere: Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _membership = State(initialValue: membership)
        self.initialTitle = initialTitle
        self.onBack = onBack
        self.content = content()
    }

    private var title: String { membership.uiState.map.map?.title ?? initialTitle }

    var body: some View {
        VStack(spacing: 0) {
            MapDetailTopBar(
                title: title,
                roleBadge: membership.uiState.roleBadge,
                action: membership.uiState.map.map?.topBarAction ?? .none,
                showsMenu: false,
                inviteCode: nil,
                actionEnabled: !membership.uiState.actionInProgress,
                onBack: { onBack(membership.uiState.joinedHere) },
                // 나가기는 바로 하지 않고 팝업에서 한 번 더 묻는다.
                onAction: { if membership.uiState.canJoin { membership.join() } else { leaveDialogVisible = true } }
            )
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            // 나갈 수 없는 상태가 되면(나가기를 마쳐 참여가 풀리면) 같이 닫힌다.
            if leaveDialogVisible, let outcome = membership.uiState.leaveOutcome {
                MoaMapConfirmDialog(
                    title: title,
                    titleSuffix: "에서 나가시겠습니까?",
                    message: outcome.confirmMessage,
                    onConfirm: {
                        leaveDialogVisible = false
                        membership.leave()
                    },
                    onDismiss: { leaveDialogVisible = false }
                )
            }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if membership.uiState.map == .loading, membership.loadTask == nil { membership.retry() }
        }
        .onChange(of: membership.uiState.left) { _, left in
            if left { onBack(false) }
        }
        .alert("요청을 처리하지 못했어요", isPresented: showsError) {
            Button("확인", role: .cancel) { membership.consumeErrorMessage() }
        } message: {
            Text(membership.uiState.errorMessage ?? "")
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { membership.uiState.errorMessage != nil },
            set: { if !$0 { membership.consumeErrorMessage() } }
        )
    }
}
