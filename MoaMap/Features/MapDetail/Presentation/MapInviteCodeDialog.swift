import SwiftUI
import UIKit

/// 초대 코드를 보여주고 복사·공유하는 모달.
struct MapInviteCodeDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let mapName: String
    let inviteCode: String
    var title = "초대코드"
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(title)
                        .moaTextStyle(typography.title3)
                        .foregroundStyle(colors.textNormal)
                    Text("초대코드를 공유하고 친구와 함께 해보세요")
                        .moaTextStyle(typography.caption2)
                        .foregroundStyle(MoaMapPrimitiveColors.gray500)
                }
                .multilineTextAlignment(.center)

                codeBox

                HStack(spacing: 4) {
                    Button(action: onDismiss) { buttonLabel("닫기", color: MoaMapPrimitiveColors.gray200) }
                    ShareLink(item: "\(mapName) 지도에 초대합니다.\n초대코드: \(inviteCode)") {
                        buttonLabel("공유하기", color: MoaMapPrimitiveColors.blue500)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(width: 300)
            .background(colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
        }
    }

    /// 복사는 안내 줄에만 건다. 어디를 눌러야 복사되는지 한눈에 보이게 한다.
    private var codeBox: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        return VStack(spacing: 8) {
            Text("초대코드")
                .moaTextStyle(typography.subtitle4)
                .foregroundStyle(MoaMapPrimitiveColors.gray500)
            Text(inviteCode)
                .moaTextStyle(typography.display1)
                .foregroundStyle(colors.textNormal)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = inviteCode
                copied = true
            } label: {
                HStack(spacing: 4) {
                    Image("Icons/copy")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    Text(copied ? "초대코드를 복사했어요" : "초대 코드 복사하기")
                        .moaTextStyle(typography.caption2)
                }
                .foregroundStyle(MoaMapPrimitiveColors.gray300)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(colors.backgroundSecondary, in: shape)
        .overlay { shape.strokeBorder(colors.lineNormal, lineWidth: 1) }
    }

    private func buttonLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .moaTextStyle(typography.button2)
            .foregroundStyle(colors.textWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
    }
}

#Preview {
    MapInviteCodeDialog(mapName: "우리끼리 맛집", inviteCode: "WWWWWW", onDismiss: {})
}
