import SwiftUI

/// 댓글 입력 줄: 흰 입력칸과 오른쪽 보내기 원. 장소 댓글과 로그 게시물 댓글이 같이 쓴다.
struct CommentInputRow<Leading: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    @Binding var text: String
    /// 화면이 빈 곳을 누를 때 키보드를 내리거나 답글 수정 때 올릴 수 있게 밖에서 받는다.
    let focused: FocusState<Bool>.Binding
    let placeholder: String
    let enabled: Bool
    let canSend: Bool
    let sending: Bool
    /// 입력은 여기서 비우지 않는다. 서버가 받아들였는지는 아직 모른다.
    let onSend: () -> Void
    /// 입력칸 왼쪽 끝 자리. 장소 댓글의 사진 첨부 + 가 쓴다.
    @ViewBuilder var leading: () -> Leading

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                leading()
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(colors.textAssistive))
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textNormal)
                    .tint(MoaMapPrimitiveColors.blue500)
                    .disabled(!enabled)
                    .focused(focused)
                    .submitLabel(.send)
                    .onSubmit { if canSend { onSend() } }
            }
            // + 는 누르는 칸 32 가운데 20 이라 왼쪽 10 이면 그림이 끝에서 16 에 선다.
            .padding(.leading, Leading.self == EmptyView.self ? 16 : 10)
            .padding(.trailing, 16)
            .frame(height: 44)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay { if focused.wrappedValue { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.primary, lineWidth: 1) } }
            .shadow(color: .black.opacity(0.04), radius: 4)

            Button(action: onSend) {
                ZStack {
                    if sending {
                        ProgressView().tint(MoaMapPrimitiveColors.white)
                    } else {
                        Image("Icons/send")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundStyle(MoaMapPrimitiveColors.white)
                    }
                }
                .frame(width: 40, height: 40)
                .background(canSend ? MoaMapPrimitiveColors.blue500 : MoaMapPrimitiveColors.gray200, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("댓글 보내기")
        }
    }
}

extension CommentInputRow where Leading == EmptyView {
    init(
        text: Binding<String>, focused: FocusState<Bool>.Binding, placeholder: String, enabled: Bool,
        canSend: Bool, sending: Bool, onSend: @escaping () -> Void
    ) {
        self.init(
            text: text, focused: focused, placeholder: placeholder, enabled: enabled, canSend: canSend,
            sending: sending, onSend: onSend, leading: { EmptyView() }
        )
    }
}
