import SwiftUI

/// 홈 상단 프로필 아이콘을 누르면 뜨는 메뉴. 시안 「모달창」: 폭 172(줄 164 + 좌우 4), 모서리 12,
/// 줄 높이 50·안쪽 16, 흰 아이콘 20·글자 body2, 줄 사이 1px 선. 바탕은 뒤를 흐리고 #4A4F52 의 60% 를 덮는다.
struct ProfileMenu: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let onProfileClick: () -> Void
    let onSettingsClick: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)

        VStack(spacing: 0) {
            row(icon: "person", label: "프로필", action: onProfileClick)
            // 시안 구분선은 높이 0 인 1px 선이라 두 줄 사이에 자리를 차지하지 않는다.
            Rectangle()
                .fill(colors.lineNormal)
                .frame(height: 1)
                .frame(height: 0)
            row(icon: "settings", label: "설정", action: onSettingsClick)
        }
        .padding(.horizontal, 4)
        .frame(width: ActionMenu.width)
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(MoaMapPrimitiveColors.gray500.opacity(0.6))
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func row(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                menuIcon(icon)
                Text(label)
                    .moaTextStyle(typography.body2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                menuIcon("arrow-right")
            }
            .foregroundStyle(colors.textWhite)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func menuIcon(_ name: String) -> some View {
        Image("Icons/\(name)").renderingMode(.template).resizable()
            .frame(width: 20, height: 20).accessibilityHidden(true)
    }
}

#Preview {
    ProfileMenu(onProfileClick: {}, onSettingsClick: {})
        .padding()
        .background(MoaMapPrimitiveColors.tabBackground)
}
