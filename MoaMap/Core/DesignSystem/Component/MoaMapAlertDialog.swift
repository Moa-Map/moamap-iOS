import SwiftUI

/// 제목과 버튼 하나만 있는 알림 팝업. 모양은 `MoaMapConfirmDialog` 와 같다. 바깥을 눌러도 닫는다.
struct MoaMapAlertDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    var buttonText = "닫기"
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            MoaMapPrimitiveColors.dialogScrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                Text(title)
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                    .minimumScaleFactor(14.0 / 18)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Button(action: onDismiss) {
                    Text(buttonText)
                        .moaTextStyle(typography.button2)
                        .foregroundStyle(colors.textWhite)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(MoaMapPrimitiveColors.blue500, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.04), radius: 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 20)
            .frame(width: 300)
            .background(colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 2) }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
        }
    }
}

#Preview {
    MoaMapAlertDialog(title: "문의가 접수됐어요", onDismiss: {})
}
