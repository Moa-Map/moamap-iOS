import SwiftUI

extension View {
    /// 신고 사유 팝업과 차단 확인 팝업을 이 화면 위에 띄운다. 토스트는 화면마다 자리가 달라 따로 단다.
    func moderationPrompts(_ viewModel: ModerationViewModel) -> some View {
        overlay {
            switch viewModel.prompt {
            case .report(_, let title):
                ReportDialog(
                    title: title,
                    isSubmitting: viewModel.submitting,
                    onSubmit: viewModel.report(reason:detail:),
                    onDismiss: viewModel.dismiss
                )
            case .block(_, let nickname):
                MoaMapConfirmDialog(
                    title: nickname ?? "이 사용자",
                    titleSuffix: nickname == nil ? "를 차단할까요?" : "님을 차단할까요?",
                    message: "모든 지도에서 이 사람의 댓글, 게시물이\n보이지 않고 알림이 오지 않아요\n설정에서 차단을 해제할 수 있어요",
                    dismissText: "취소",
                    confirmText: "차단하기",
                    onConfirm: viewModel.confirmBlock,
                    onDismiss: viewModel.dismiss
                )
            case nil:
                EmptyView()
            }
        }
    }

    /// 신고·차단 결과와 `notify` 로 넘긴 안내를 띄운다.
    func moderationToast(_ viewModel: ModerationViewModel, bottomInset: CGFloat = 0) -> some View {
        moaToast(Binding(get: { viewModel.toast }, set: { if $0 == nil { viewModel.consumeToast() } }), bottomInset: bottomInset)
    }
}
