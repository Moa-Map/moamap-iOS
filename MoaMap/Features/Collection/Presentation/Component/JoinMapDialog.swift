import SwiftUI

/// Figma 초대 코드 모달.
struct JoinMapDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @FocusState private var isCodeFocused: Bool
    /// 입력창에 붙는 글자. 걸러진 값이 그대로면 TextField 가 다시 그려지지 않아 넘친 글자가 남는다. 여기서 되돌린다.
    @State private var draft = ""
    let state: JoinMapEditing
    /// 입력을 넘기고 걸러져 남은 코드를 돌려받는다.
    let onCodeChange: (String) -> String
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            MoaMapPrimitiveColors.dialogScrim
                .ignoresSafeArea()
                // 입력 중이면 닫지 않고 키보드만 내린다.
                .onTapGesture { if isCodeFocused { isCodeFocused = false } else { onDismiss() } }
                .accessibilityHidden(true)
            content
                .padding(.horizontal, 20)
        }
        .accessibilityAction(.escape) { onDismiss() }
        .onChange(of: draft) { _, input in
            let accepted = onCodeChange(input)
            if accepted != input { draft = accepted }
        }
        .onChange(of: state.code, initial: true) { _, code in
            if draft != code { draft = code }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            Text("지도 참여하기")
                .moaTextStyle(typography.title3)
                .accessibilityAddTraits(.isHeader)
            (
                Text("친구에게 ") +
                Text("초대 코드").foregroundColor(colors.primary) +
                Text("를 받으세요")
            )
            .moaTextStyle(typography.subtitle2)

            HStack(alignment: .top, spacing: 12) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("#")
                        .font(.custom(MoaMapFontName.nanumSquareBold, size: 30))
                        .kerning(-0.6)
                        .frame(width: 19, height: 39)
                        .accessibilityHidden(true)
                    TextField("", text: $draft)
                        .font(.custom(MoaMapFontName.nanumSquareBold, size: 30))
                        .kerning(-0.6)
                        .multilineTextAlignment(.center)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(onSubmit)
                        .focused($isCodeFocused)
                        .disabled(state.submitting)
                        .frame(width: 181, height: 39)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(MoaMapPrimitiveColors.black).frame(height: 2)
                        }
                        .accessibilityLabel("초대 코드")
                }
                Button(action: onSubmit) {
                    ZStack {
                        if state.submitting {
                            ProgressView()
                                .tint(colors.textWhite)
                                .frame(width: 20, height: 20)
                        } else {
                            Image("Icons/arrow-forward")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundStyle(colors.textWhite)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(state.canSubmit ? colors.primary : MoaMapPrimitiveColors.gray200, in: Circle())
                }
                .buttonStyle(JoinMapSubmitButtonStyle())
                .disabled(!state.canSubmit)
                .accessibilityLabel("지도 참여하기")
            }
            .frame(height: 40)

            if let message = state.errorMessage {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.statusAlert)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(colors.textNormal)
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
        .frame(maxWidth: 353)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(colors.primary, lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.04), radius: 4)
        // 모달 안의 빈 곳을 누르면 키보드를 내린다.
        .contentShape(Rectangle())
        .onTapGesture { isCodeFocused = false }
    }
}

#Preview {
    JoinMapDialog(
        state: JoinMapEditing(code: "A1B2C3", errorMessage: "코드를 다시 확인해주세요"),
        onCodeChange: { $0 },
        onSubmit: {},
        onDismiss: {}
    )
}

private struct JoinMapSubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
