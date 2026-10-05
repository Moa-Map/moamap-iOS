import SwiftUI

/// Figma 참여 코드 모달.
struct JoinMapDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @FocusState private var isCodeFocused: Bool
    let state: JoinMapEditing
    let onCodeChange: (String) -> Void
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
                .accessibilityHidden(true)
            content
                .padding(.horizontal, 20)
        }
        .onAppear { isCodeFocused = true }
        .accessibilityAction(.escape) { onDismiss() }
    }

    private var code: Binding<String> {
        Binding(get: { state.code }, set: onCodeChange)
    }

    private var content: some View {
        VStack(spacing: 12) {
            Text("지도 참여하기")
                .moaTextStyle(typography.title3)
                .accessibilityAddTraits(.isHeader)
            (
                Text("친구에게 ") +
                Text("참여 코드").foregroundColor(colors.primary) +
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
                    TextField("", text: code)
                        .font(.custom(MoaMapFontName.nanumSquareBold, size: 30))
                        .kerning(-0.6)
                        .multilineTextAlignment(.center)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isCodeFocused)
                        .submitLabel(.done)
                        .onSubmit(onSubmit)
                        .disabled(state.submitting)
                        .frame(width: 181, height: 39)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(MoaMapPrimitiveColors.black).frame(height: 2)
                        }
                        .accessibilityLabel("참여 코드")
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
    }
}

#Preview {
    JoinMapDialog(
        state: JoinMapEditing(code: "A1B2C3", errorMessage: "코드를 다시 확인해주세요"),
        onCodeChange: { _ in },
        onSubmit: {},
        onDismiss: {}
    )
}

private struct JoinMapSubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
