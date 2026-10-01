import SwiftUI

/// 인기순·최신순. 탐색 탭과 커뮤니티 지도 전체보기가 같이 쓴다.
struct CommunityMapSortRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let selected: MapSortOrder
    let onSelect: (MapSortOrder) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MapSortOrder.allCases) { order in
                let isSelected = order == selected
                Button {
                    onSelect(order)
                } label: {
                    Text(order.title)
                        .moaTextStyle(isSelected ? typography.button2 : typography.button3)
                        .foregroundStyle(isSelected ? colors.textNormal : colors.textAssistive)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private extension MapSortOrder {
    var title: String {
        switch self {
        case .popular: "인기순"
        case .latest: "최신순"
        }
    }
}

#Preview {
    CommunityMapSortRow(selected: .popular) { _ in }
        .padding()
}
