import SwiftUI

/// Figma 참여 코드 모달. 제출 동작은 지도 참여 API 연동 시 연결한다.
struct JoinMapDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityHidden(true)
            content
                .padding(.horizontal, 20)
        }
        .onAppear { isCodeFocused = true }
        .accessibilityAction(.escape) { close() }
    }

    private func close() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dismiss()
        }
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
                    TextField("", text: $code)
                        .font(.custom(MoaMapFontName.nanumSquareBold, size: 30))
                        .kerning(-0.6)
                        .multilineTextAlignment(.center)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isCodeFocused)
                        .submitLabel(.done)
                        .onSubmit { isCodeFocused = false }
                        .onChange(of: code) { _, value in
                            code = value.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.uppercased()
                        }
                        .frame(width: 181, height: 39)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(MoaMapPrimitiveColors.black).frame(height: 2)
                        }
                        .accessibilityLabel("참여 코드")
                }
                Button {} label: {
                    Image("Icons/arrow-forward")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textWhite)
                        .padding(4)
                        .background(MoaMapPrimitiveColors.gray200, in: Circle())
                }
                .buttonStyle(JoinMapSubmitButtonStyle())
                .disabled(true)
                .accessibilityLabel("지도 참여하기")
            }
            .frame(height: 40)
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
    JoinMapDialog()
}

private struct JoinMapSubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
