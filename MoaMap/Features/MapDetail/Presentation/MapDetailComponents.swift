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

/// 지도 상세 상단바. 참여 전에는 우측에 참여하기가 뜬다.
struct MapDetailTopBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    let roleBadge: String?
    let showsJoin: Bool
    /// 요청이 도는 동안 잠근다. 라벨은 그대로 두고 누를 수만 없게 한다.
    let joinEnabled: Bool
    let onBack: () -> Void
    let onJoin: () -> Void

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
            // 좌우 버튼과 겹치지 않도록 안쪽으로 밀어 둔다.
            .padding(.horizontal, 72)

            HStack {
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
                if showsJoin {
                    Button(action: onJoin) {
                        Text("참여하기")
                            .moaTextStyle(typography.button2)
                            .foregroundStyle(joinEnabled ? MoaMapPrimitiveColors.blue600 : colors.textDisable)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(!joinEnabled)
                    .padding(.trailing, 20)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(height: 58)
        .background(colors.backgroundSecondary)
    }
}

struct MapDetailTabBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let selection: MapDetailTab
    let onSelect: (MapDetailTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MapDetailTab.allCases, id: \.self) { tab in
                let selected = tab == selection
                Button { onSelect(tab) } label: {
                    Text(tab.title)
                        .moaTextStyle(selected ? typography.subtitle1 : typography.subtitle2)
                        .foregroundStyle(selected ? MoaMapPrimitiveColors.yellow900 : colors.textAssistive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected ? MoaMapPrimitiveColors.yellow100 : MoaMapPrimitiveColors.yellow50, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5)
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
        MapDetailTopBar(title: "서울 데이트 지도", roleBadge: "방장", showsJoin: false, joinEnabled: true, onBack: {}, onJoin: {})
        MapDetailTopBar(title: "성수 카페 투어", roleBadge: nil, showsJoin: true, joinEnabled: true, onBack: {}, onJoin: {})
        MapDetailTabBar(selection: .places) { _ in }.padding(.horizontal, 20)
        HStack(spacing: 40) {
            MyLocationButton(inProgress: false) {}
            MapDimensionToggle(is3D: false) {}
        }
    }
    .background(Color.gray.opacity(0.2))
}
