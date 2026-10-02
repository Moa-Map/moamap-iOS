import SwiftUI

nonisolated enum MapDetailTab: CaseIterable, Sendable {
    case places
    case logs

    var title: String {
        switch self {
        case .places: "장소"
        case .logs: "로그"
        }
    }
}

/// 지도 상세 상단바. 우측은 참여 전에는 참여하기, 참여한 뒤에는 메뉴다.
struct MapDetailTopBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    let roleBadge: String?
    let action: MapDetailAction
    let showsMenu: Bool
    /// nil 이면 초대코드 버튼을 띄우지 않는다.
    let inviteCode: String?
    /// 요청이 도는 동안 잠근다. 라벨은 그대로 두고 누를 수만 없게 한다.
    let actionEnabled: Bool
    let onBack: () -> Void
    let onAction: () -> Void
    var onInviteCode: () -> Void = {}
    var onMenu: () -> Void = {}

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                Text(title)
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(1)
                if let roleBadge {
                    Text(roleBadge)
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(MoaMapPrimitiveColors.blue900)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(MoaMapPrimitiveColors.blue50, in: Capsule())
                        .overlay { Capsule().strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) }
                }
            }
            // 좌우 버튼과 겹치지 않도록 안쪽으로 밀어 둔다. 초대코드가 붙으면 그만큼 더 민다.
            .padding(.horizontal, inviteCode == nil ? 72 : 132)

            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("뒤로가기")
                .padding(.leading, 6)
                Spacer()
                if inviteCode != nil {
                    textAction("초대코드", color: MoaMapPrimitiveColors.blue600, enabled: true, action: onInviteCode)
                }
                trailingAction
            }
            .padding(.trailing, 20)
            .buttonStyle(.plain)
        }
        .frame(height: 58)
        .background(colors.backgroundSecondary)
    }

    @ViewBuilder
    private var trailingAction: some View {
        if action == .join {
            textAction("참여하기", color: MoaMapPrimitiveColors.blue600, enabled: actionEnabled, action: onAction)
        } else if showsMenu {
            // 나가기가 도는 동안에도 잠근다. 메뉴를 다시 열어 두 번 누를 수 없게 한다.
            Button(action: onMenu) {
                Image("Icons/menu")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(actionEnabled ? colors.textNormal : colors.textDisable)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!actionEnabled)
            .accessibilityLabel("지도 메뉴")
        } else if action == .leave {
            textAction("나가기", color: colors.statusAlert, enabled: actionEnabled, action: onAction)
        }
    }

    private func textAction(_ label: String, color: Color, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .moaTextStyle(typography.button2)
                .foregroundStyle(enabled ? color : colors.textDisable)
                .lineLimit(1)
                .fixedSize()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
    }
}

/// 상단바 메뉴. 나갈 수 없는 사람에게는 나가기 줄을 넣지 않는다.
struct MapDetailMenu: View {
    let canLeave: Bool
    let onMembers: () -> Void
    let onManage: () -> Void
    let onLeave: () -> Void

    var body: some View {
        var items = [
            ActionMenuItem(icon: "person", label: "멤버 관리", action: onMembers),
            ActionMenuItem(icon: "map", label: "지도 관리", action: onManage)
        ]
        if canLeave { items.append(ActionMenuItem(icon: "out", label: "나가기", action: onLeave)) }
        return ActionMenu(items: items)
    }
}

nonisolated extension LeaveOutcome {
    var confirmMessage: String {
        switch self {
        case .leave: "나가시면 모음 탭에서 지도가 사라집니다"
        case .leaveNeedsInviteCode: "나가시면 모음 탭에서 지도가 사라집니다\n다시 들어오려면 초대코드가 필요합니다"
        case .deleteMap: "혼자 남은 지도라 나가면 지도가 삭제됩니다\n되돌릴 수 없습니다"
        }
    }
}

struct MapDetailTabBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let selection: MapDetailTab
    let onSelect: (MapDetailTab) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(MapDetailTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button { onSelect(tab) } label: {
                    Text(tab.title)
                        .moaTextStyle(selected ? typography.button0 : typography.button1)
                        .foregroundStyle(selected ? MoaMapPrimitiveColors.yellow900 : colors.textAssistive)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(selected ? MoaMapPrimitiveColors.yellow100 : MoaMapPrimitiveColors.yellow50, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
    }
}

/// 3D 가 위, 2D 가 아래로 붙은 세로 토글. 고른 쪽이 파랗게 채워진다.
struct MapDimensionToggle: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let is3D: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            segment("3D", selected: is3D)
            segment("2D", selected: !is3D)
        }
        .frame(width: 48, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        // 조각마다 테두리를 주면 맞닿는 변에 선이 생긴다. 바깥에 한 번만 덮는다.
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) }
    }

    private func segment(_ label: String, selected: Bool) -> some View {
        Button {
            // 이미 고른 쪽을 다시 눌러도 바뀔 게 없다.
            if !selected { onToggle() }
        } label: {
            Text(label)
                .moaTextStyle(typography.button2)
                .foregroundStyle(selected ? colors.textWhite : MoaMapPrimitiveColors.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? MoaMapPrimitiveColors.blue500 : colors.backgroundSecondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 내 위치로 이동. 좌표를 찾는 동안에는 눌리지 않는다. 연타로 조회가 겹치면 카메라가 두 번 튄다.
struct MyLocationButton: View {
    @Environment(\.moaColors) private var colors

    let inProgress: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("Icons/location")
                .renderingMode(.template)
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(inProgress ? MoaMapPrimitiveColors.gray100 : MoaMapPrimitiveColors.blue500)
                .padding(8)
                .background(colors.backgroundSecondary, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(.plain)
        .disabled(inProgress)
        .accessibilityLabel("내 위치로 이동")
    }
}

#Preview {
    VStack(spacing: 20) {
        MapDetailTopBar(
            title: "서울 데이트 지도", roleBadge: "방장", action: .leaveDisabled, showsMenu: true,
            inviteCode: nil, actionEnabled: true, onBack: {}, onAction: {}
        )
        MapDetailTopBar(
            title: "성수 카페 투어", roleBadge: nil, action: .join, showsMenu: false,
            inviteCode: nil, actionEnabled: true, onBack: {}, onAction: {}
        )
        MapDetailTopBar(
            title: "우리끼리만 아는 성수동 맛집 모음", roleBadge: nil, action: .leave, showsMenu: true,
            inviteCode: "A1B2C3", actionEnabled: true, onBack: {}, onAction: {}
        )
        MapDetailTopBar(
            title: "서울 무장애 여행지", roleBadge: nil, action: .leave, showsMenu: false,
            inviteCode: nil, actionEnabled: true, onBack: {}, onAction: {}
        )
        MapDetailMenu(canLeave: true, onMembers: {}, onManage: {}, onLeave: {})
        MapDetailTabBar(selection: .places) { _ in }.padding(.horizontal, 20)
        HStack(spacing: 40) {
            MyLocationButton(inProgress: false) {}
            MapDimensionToggle(is3D: false) {}
        }
    }
    .background(Color.gray.opacity(0.2))
}
