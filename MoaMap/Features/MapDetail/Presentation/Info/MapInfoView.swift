import SwiftUI

/// 지도 정보. 대표 사진·지도명·제작자와 지도 소개를 보여 준다. 방장·관리자는 여기서 수정으로 간다.
struct MapInfoView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    static let heroHeight: CGFloat = 262

    let map: MapDetail
    let onBack: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MapIntroHero(title: map.title, ownerName: map.ownerName, imageURL: map.imageURL, height: Self.heroHeight)
                introSection
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) { topBar }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) { MoaMapTopBarIcon(name: "arrow-left") }
                .accessibilityLabel("뒤로가기")
            Spacer()
            if map.canEditInfo {
                Button(action: onEdit) { MoaMapTopBarIcon(name: "edit") }
                    .accessibilityLabel("지도 정보 수정")
            }
        }
        .buttonStyle(.plain)
        // 아이콘은 44 칸 가운데에 놓이므로 그만큼 덜 띄워야 시안의 20 에 맞는다.
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding - 6)
        .frame(height: 58)
    }

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MapIntroSectionTitle(text: "지도 소개")
            VStack(alignment: .leading, spacing: 8) {
                if !map.tags.isEmpty { MapIntroTagRow(tags: map.tags) }
                if let description = map.description {
                    Text(description)
                        .moaTextStyle(typography.body3)
                        .foregroundStyle(colors.textAlternative)
                } else if map.tags.isEmpty {
                    Text("아직 지도 소개가 없어요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    MapInfoView(
        map: MapDetail(
            id: 1, title: "숭실대 주변 맛집", description: "학교 주변에서 함께 찾아본 맛집을 모아봤어요", imageURL: nil,
            ownerName: "모아", type: .community, role: .owner, tags: ["맛집", "숭실대"], memberCount: 3, placeCount: 10,
            joined: true, personal: false, inviteCode: nil
        ),
        onBack: {},
        onEdit: {}
    )
}
