    import SwiftUI

/// 한 번 더 묻는 확인 팝업. 확인을 눌러도 스스로 닫지 않는다.
///
/// 제목은 `title` + `titleSuffix` 를 늘 한 줄로 보인다. 넘치면 글자를 줄이고, 그래도 넘치면
/// `title` 끝만 말줄임한다. 두 줄이 되면 "나가시겠습니 / 까?" 처럼 끊긴다.
struct MoaMapConfirmDialog: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    var titleSuffix = ""
    let message: String
    var dismissText = "닫기"
    /// 시안마다 다르다(나가기 확인 Gray200, 댓글 삭제 Gray100).
    var dismissColor = MoaMapPrimitiveColors.gray200
    var confirmText = "확인"
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    /// 본문(14)보다 작아지지 않게 한다.
    private static let titleScales: [CGFloat] = [1, 16.0 / 18, 14.0 / 18]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    titleText
                    Text(message)
                        .moaTextStyle(typography.caption2)
                        .foregroundStyle(colors.textAlternative)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 4) {
                    button(dismissText, color: dismissColor, action: onDismiss)
                    button(confirmText, color: MoaMapPrimitiveColors.blue500, action: onConfirm)
                }
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

    private var titleText: some View {
        let style = typography.title3
        return ViewThatFits(in: .horizontal) {
            ForEach(Self.titleScales, id: \.self) { scale in
                Text(title + titleSuffix)
                    .moaTextStyle(style.scaled(scale))
                    .lineLimit(1)
                    .fixedSize()
            }
            HStack(spacing: 0) {
                Text(title).lineLimit(1).truncationMode(.tail)
                Text(titleSuffix).lineLimit(1).fixedSize()
            }
            .moaTextStyle(style.scaled(Self.titleScales.last ?? 1))
        }
        .foregroundStyle(colors.textNormal)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + titleSuffix)
        .accessibilityAddTraits(.isHeader)
    }

    private func button(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.04), radius: 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private nonisolated extension MoaMapTextStyle {
    /// 폭이 글자 크기에 비례하도록 자간·줄 높이도 같은 비율로 줄인다.
    func scaled(_ scale: CGFloat) -> MoaMapTextStyle {
        MoaMapTextStyle(fontName: fontName, size: size * scale, lineHeight: lineHeight * scale, letterSpacing: letterSpacing * scale)
    }
}

#Preview {
    MoaMapConfirmDialog(
        title: "우리끼리만 아는 성수동 맛집 모음 지도",
        titleSuffix: "에서 나가시겠습니까?",
        message: "나가시면 모음 탭에서 지도가 사라집니다\n다시 들어오려면 초대코드가 필요합니다",
        onConfirm: {},
        onDismiss: {}
    )
}
