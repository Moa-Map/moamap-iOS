import SwiftUI

struct OfficialMapListView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: OfficialMapListViewModel
    @State private var guideVisible = false
    private let onMapClick: (OfficialMap) -> Void

    /// 부모가 다시 그려져도 처음 받은 ViewModel 을 쓴다. 바뀌면 받아 둔 목록이 사라진다.
    init(viewModel: OfficialMapListViewModel, onMapClick: @escaping (OfficialMap) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onMapClick = onMapClick
    }

    var body: some View {
        VStack(spacing: 12) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    guide
                        .zIndex(1)
                    LazyVStack(spacing: 8) { content }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
        }
        // 시안 배경은 단색 Background/Primary(#E6F6FF)다. iOS 의 backgroundPrimary 토큰은 그라데이션이라 쓰지 않는다.
        .background { MoaMapPrimitiveColors.blue50.ignoresSafeArea() }
        // 말풍선 밖을 누르면 닫는다.
        .contentShape(Rectangle())
        .onTapGesture { guideVisible = false }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.refresh() }
    }

    private var topBar: some View {
        ZStack {
            Text("공식지도")
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
            HStack {
                Button { dismiss() } label: {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                Spacer()
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 58)
    }

    private var guide: some View {
        MoaMapGuideRow(text: "공식지도가 궁금하신가요?", isPresented: $guideVisible, accessibilityHint: "공식지도 안내를 엽니다") {
            MoaMapTooltip(tailInset: 14, fill: .solid(MoaMapPrimitiveColors.blue800)) {
                Text("모아맵이 공공데이터로 만든 지도예요.\n참여하면 모음 탭에서 바로 볼 수 있어요.")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textWhite)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState {
        case .loading:
            CommunityMapsPlaceholder { ProgressView() }
        case .failed(let message):
            CommunityMapsPlaceholder {
                CommunityMapsError(message: message) { viewModel.retry() }
            }
        case .loaded(let maps) where maps.isEmpty:
            CommunityMapsPlaceholder {
                Text("아직 등록된 공식지도가 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        case .loaded(let maps):
            ForEach(maps) { map in
                Button { onMapClick(map) } label: { OfficialMapCard(map: map) }
                    .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG
@MainActor
final class PreviewOfficialMapRepository: OfficialMapRepository {
    func fetchOfficialMaps() async throws -> [OfficialMap] {
        [
            OfficialMap(id: 6, title: "화장실 위치", description: "공공데이터 기반 공중화장실 위치", imageURL: nil, joined: false),
            OfficialMap(id: 7, title: "지도 이름", description: "지도 관련 설명 1줄", imageURL: nil, joined: true)
        ]
    }
}

#Preview {
    NavigationStack {
        OfficialMapListView(viewModel: OfficialMapListViewModel(repository: PreviewOfficialMapRepository()), onMapClick: { _ in })
    }
}
#endif
