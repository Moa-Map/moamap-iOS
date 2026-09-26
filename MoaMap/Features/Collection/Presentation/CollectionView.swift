import SwiftUI

struct CollectionView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    let viewModel: CollectionViewModel
    let onHome: () -> Void
    @State private var showsInviteDialog = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    tabs
                    if viewModel.uiState.selectedTab == .private { importActions }
                    mapsContent
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task { viewModel.refresh() }
        .fullScreenCover(isPresented: $showsInviteDialog) {
            JoinMapDialog()
                .presentationBackground(.clear)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onHome) {
                Image("moa-logo").resizable().scaledToFit().frame(width: 74, height: 44)
            }
            .accessibilityLabel("탐색 탭으로 이동")
            Spacer(minLength: 4)
            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showsInviteDialog = true
                }
            } label: {
                HStack(spacing: 2) {
                    icon("key", size: 24)
                    Text("초대 코드").moaTextStyle(typography.button2)
                }
                .frame(minHeight: 44)
            }
            Button {} label: {
                HStack(spacing: 2) {
                    icon("add", size: 24)
                    Text("새 지도").moaTextStyle(typography.button2)
                }
                .padding(.leading, 8).padding(.trailing, 16).padding(.vertical, 8)
                .foregroundStyle(colors.textWhite)
                .background(colors.primary, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(colors.textNormal)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .frame(height: 52)
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(CollectionMapType.allCases, id: \.self) { type in
                let selected = viewModel.uiState.selectedTab == type
                Button { viewModel.selectTab(type) } label: {
                    Text(type == .community ? "커뮤니티" : "프라이빗")
                        .moaTextStyle(selected ? typography.subtitle3 : typography.subtitle2)
                        .foregroundStyle(selected ? MoaMapPrimitiveColors.yellow900 : colors.textAssistive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selected ? MoaMapPrimitiveColors.yellow100 : MoaMapPrimitiveColors.yellow50, in: Capsule())
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
    }

    @ViewBuilder private var mapsContent: some View {
        switch viewModel.uiState.currentMaps {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).frame(height: 200)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).moaTextStyle(typography.body2).foregroundStyle(colors.textAssistive)
                Button("다시 시도") { viewModel.retry() }
                    .moaTextStyle(typography.button2)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .foregroundStyle(colors.textWhite)
                    .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: .infinity).frame(height: 200)
        case .loaded(let maps):
            if maps.isEmpty {
                Text(viewModel.uiState.selectedTab == .community ? "아직 참여한 지도가 없어요" : "아직 만든 지도가 없어요")
                    .moaTextStyle(typography.body2).foregroundStyle(colors.textAssistive)
                    .frame(maxWidth: .infinity).frame(height: 200)
            } else if viewModel.uiState.selectedTab == .community {
                mapList(maps, showsMembers: true)
            } else {
                let sections = PrivateMapSections(maps: maps)
                VStack(alignment: .leading, spacing: 20) {
                    section("나만의 지도", maps: sections.personal)
                    section("전체", maps: sections.others)
                }
            }
        }
    }

    private func mapList(_ maps: [MyMap], showsMembers: Bool) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(maps) { map in CollectionMapCard(map: map, showsMembers: showsMembers) }
        }
    }

    @ViewBuilder private func section(_ title: String, maps: [MyMap]) -> some View {
        if !maps.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).moaTextStyle(typography.title2).foregroundStyle(colors.textNormal)
                    .padding(.horizontal, 4)
                mapList(maps, showsMembers: false)
            }
        }
    }

    private var importActions: some View {
        HStack(spacing: 4) {
            importCard(iconName: "instagram-logo", title: "인스타그램", subtitle: "장소 찾기", background: Color(argb: 0xFFFFF5FB), titleColor: Color(argb: 0xFFAF0069))
            importCard(iconName: "map", title: "외부 지도", subtitle: "불러오기", background: MoaMapPrimitiveColors.yellow50, titleColor: MoaMapPrimitiveColors.yellow800)
        }
    }

    private func importCard(iconName: String, title: String, subtitle: String, background: Color, titleColor: Color) -> some View {
        Button {} label: {
            HStack(spacing: 8) {
                if iconName == "map" {
                    icon(iconName, size: 24).foregroundStyle(colors.secondary)
                } else {
                    Image("Icons/\(iconName)").resizable().frame(width: 24, height: 24)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).moaTextStyle(typography.subtitle2).foregroundStyle(titleColor)
                    Text(subtitle).moaTextStyle(typography.body1).foregroundStyle(colors.textNormal)
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                icon("arrow-outward", size: 24).foregroundStyle(colors.textNormal)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity).frame(height: 72)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
        .buttonStyle(.plain)
    }

    private func icon(_ name: String, size: CGFloat) -> some View {
        Image("Icons/\(name)").renderingMode(.template).resizable()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

#if DEBUG
@MainActor
final class PreviewCollectionRepository: CollectionRepository {
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        (1...3).map {
            MyMap(id: Int64($0), title: $0 == 1 && type == .private ? "나만의 지도" : "서울 팝업스토어 맵", imageURL: nil, memberCount: 24, placeCount: 116, official: false, personal: $0 == 1 && type == .private)
        }
    }
}

#Preview {
    CollectionView(viewModel: CollectionViewModel(repository: PreviewCollectionRepository()), onHome: {})
}
#endif
