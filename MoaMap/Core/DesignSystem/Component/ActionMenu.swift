import SwiftUI

struct ActionMenuItem: Identifiable {
    /// `Icons/` 아래 에셋 이름.
    let icon: String
    let label: String
    /// 신고처럼 되돌리기 어려운 일. 빨간 글씨로 둔다.
    var isDestructive = false
    let action: () -> Void

    var id: String { label }
}

/// 줄 사이에 구분선을 넣는 팝업 메뉴.
struct ActionMenu: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    enum Style {
        /// 다른 화면으로 넘어가는 줄. 오른쪽에 화살표를 둔다.
        case navigation
        /// 그 자리에서 바로 하는 일(꾹 눌러 띄우는 메뉴). 화살표 없이 아이콘·글씨를 키운다.
        case command
    }

    static let width: CGFloat = 172
    /// 시안의 메뉴 신고 빨강. 디자인 토큰에 없는 색이다.
    static let destructiveColor = Color(argb: 0xFFFF_4347)

    let items: [ActionMenuItem]
    var cornerRadius: CGFloat = 12
    /// 뒤가 비치는 어두운 메뉴. 흰 글씨를 쓴다.
    var dark = false
    var style = Style.navigation

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(colors.lineNormal).frame(height: 1)
                }
                row(item)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: Self.width)
        .background {
            if dark {
                shape.fill(.ultraThinMaterial)
                shape.fill(MoaMapPrimitiveColors.gray500.opacity(0.7))
            } else {
                shape.fill(colors.backgroundSecondary)
                shape.strokeBorder(MoaMapPrimitiveColors.blue600, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(dark ? 0 : 0.04), radius: 4)
    }

    private func row(_ item: ActionMenuItem) -> some View {
        Button(action: item.action) {
            HStack(spacing: 8) {
                icon(item.icon)
                Text(item.label)
                    .moaTextStyle(style == .command ? typography.body1 : typography.body2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if style == .navigation { icon("arrow-right") }
            }
            .foregroundStyle(item.isDestructive ? Self.destructiveColor : dark ? colors.textWhite : colors.textNormal)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func icon(_ name: String) -> some View {
        let size: CGFloat = style == .command ? 24 : 20
        return Image("Icons/\(name)").renderingMode(.template).resizable()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

extension AnyTransition {
    /// 오른쪽 위 버튼에서 펼쳐지는 메뉴. 닫을 때는 애니메이션 없이 바로 사라진다.
    static let dropdownMenu = AnyTransition.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing))
}

extension Animation {
    static let dropdownMenu = Animation.easeOut(duration: 0.15)
}

#Preview("꾹 누름") {
    ActionMenu(items: [
        ActionMenuItem(icon: "block", label: "차단하기") {},
        ActionMenuItem(icon: "report", label: "신고하기", isDestructive: true) {}
    ], dark: true, style: .command)
    .padding()
    .background(Color.gray)
}

#Preview {
    ActionMenu(items: [
        ActionMenuItem(icon: "person", label: "프로필") {},
        ActionMenuItem(icon: "settings", label: "설정") {}
    ])
    .padding()
}
