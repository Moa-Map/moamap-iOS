import MapboxMaps
import SwiftUI

struct MapIntroView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: MapIntroViewModel
    /// 지도 이름과 공식지도인지를 넘긴다. 특수 공식지도는 지도 상세가 아니라 전용 화면으로 가야 해서 받는 쪽이 고른다.
    private let onPreview: (_ title: String, _ official: Bool) -> Void
    private let onJoined: (_ title: String, _ official: Bool) -> Void
    /// 공중화장실 지도의 작은 지도. 화장실은 장소가 아니라 그냥 두면 비어 보인다.
    private let restroomPreview: (() -> RestroomPreviewMap)?
    /// 이 화면은 권한을 묻지 않는다. 이미 허용돼 있을 때만 내 위치가 보인다.
    private let showsMyLocation: Bool

    @State private var viewport: Viewport = .initial(.center(MapCameraDefaults.center), padding: .init())
    /// 장소가 도착하면 처음 한 번만 맞추고 그다음은 사용자가 움직인 대로 둔다.
    @State private var cameraSettled = false

    init(
        viewModel: MapIntroViewModel,
        onPreview: @escaping (_ title: String, _ official: Bool) -> Void,
        onJoined: @escaping (_ title: String, _ official: Bool) -> Void,
        restroomPreview: (() -> RestroomPreviewMap)? = nil,
        showsMyLocation: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onPreview = onPreview
        self.onJoined = onJoined
        self.restroomPreview = restroomPreview
        self.showsMyLocation = showsMyLocation
    }

    private var title: String { viewModel.uiState.map.map?.title ?? "" }
    private var official: Bool { viewModel.uiState.map.map?.type == .official }

    var body: some View {
        ZStack(alignment: .bottom) {
            colors.backgroundSecondary.ignoresSafeArea()

            switch viewModel.uiState.map {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                failure(message)
            case .loaded(let map):
                content(map)
                // 이미 참여한 지도는 버튼이 할 일이 없다. 상세로 가는 길은 미리보기가 있다.
                if !map.joined { joinButton }
            }
        }
        .overlay(alignment: .topLeading) { backButton }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.refresh() }
        .onChange(of: viewModel.uiState.joined) { _, joined in
            if joined { onJoined(title, official) }
        }
        .alert("참여하지 못했어요", isPresented: showsError) {
            Button("확인", role: .cancel) { viewModel.consumeErrorMessage() }
        } message: {
            Text(viewModel.uiState.errorMessage ?? "")
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { viewModel.uiState.errorMessage != nil },
            set: { if !$0 { viewModel.consumeErrorMessage() } }
        )
    }

    private func content(_ map: MapDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MapIntroHero(title: map.title, ownerName: map.ownerName, imageURL: map.imageURL)

                VStack(alignment: .leading, spacing: 20) {
                    // 소개할 게 없으면 제목만 남은 빈 섹션이 된다. 통째로 건너뛴다.
                    if !map.tags.isEmpty || map.description != nil {
                        introSection(map)
                        MapIntroDivider()
                    }
                    mapSection
                    if !viewModel.uiState.previewPlaces.isEmpty {
                        MapIntroDivider()
                        placesSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                // 하단 고정 버튼에 마지막 섹션이 가리지 않게 한다.
                .padding(.bottom, map.joined ? 20 : 86)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
    }

    private func introSection(_ map: MapDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MapIntroSectionTitle(text: "지도 소개")
            VStack(alignment: .leading, spacing: 8) {
                if !map.tags.isEmpty { MapIntroTagRow(tags: map.tags) }
                if let description = map.description {
                    Text(description)
                        .moaTextStyle(typography.body3)
                        .foregroundStyle(colors.textAlternative)
                }
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MapIntroSectionTitle(text: "지도")
            previewMap
                .frame(height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    previewButton.padding(10)
                }
                .onAppear(perform: settleCamera)
                .onChange(of: viewModel.uiState.places) { settleCamera() }
        }
    }

    /// 참여 전에는 장소 상세도, 묶음 펼치기도 열지 않는다. 그릴 뿐이다.
    @ViewBuilder
    private var previewMap: some View {
        if let restroomPreview, OfficialMapKind(official: official, title: title) == .restroom {
            restroomPreview()
        } else {
            PlaceMarkerMap(
                places: viewModel.uiState.places,
                viewport: $viewport,
                allowsRotation: false,
                showsMyLocation: showsMyLocation
            )
        }
    }

    private func settleCamera() {
        let places = viewModel.uiState.places
        guard !cameraSettled, !places.isEmpty else { return }
        viewport = .initial(InitialCamera(places: places, deviceLocation: nil), padding: .init(top: 32, leading: 32, bottom: 32, trailing: 32))
        cameraSettled = true
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            MapIntroSectionTitle(text: "장소 목록")
            VStack(spacing: 4) {
                ForEach(viewModel.uiState.previewPlaces) { place in
                    MapIntroPlaceItem(place: place)
                }
            }
            if viewModel.uiState.hasMorePlaces {
                // 전체 장소 목록 화면이 없어 미리보기와 같이 상세로 보낸다.
                Button { onPreview(title, official) } label: {
                    Text("더보기")
                        .moaTextStyle(typography.caption0)
                        .underline()
                        .foregroundStyle(MoaMapPrimitiveColors.gray300)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, -4)
            }
        }
    }

    private var previewButton: some View {
        Button { onPreview(title, official) } label: {
            Text("미리보기")
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textWhite)
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(MoaMapPrimitiveColors.blue500, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.08), radius: 5)
        }
        .buttonStyle(.plain)
    }

    private var joinButton: some View {
        let enabled = !viewModel.uiState.joining
        return Button { viewModel.join() } label: {
            Text("참여하기")
                .moaTextStyle(typography.button0)
                .foregroundStyle(colors.textWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? MoaMapPrimitiveColors.blue500 : MoaMapPrimitiveColors.gray100, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.08), radius: 5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    /// 히어로 위에서는 흰색이라야 읽힌다. 로딩·오류 화면은 밝은 배경이라 어두운 색을 쓴다.
    private var backButton: some View {
        Button { dismiss() } label: {
            Image("Icons/arrow-left")
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(viewModel.uiState.map.map == nil ? colors.textNormal : colors.textWhite)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("뒤로가기")
        .padding(.leading, 14)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
                .multilineTextAlignment(.center)
            Button("다시 시도") { viewModel.retry() }
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textNormal)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
@MainActor
final class PreviewMapDetailRepository: MapDetailRepository {
    func fetchMapDetail(mapID: Int64) async throws -> MapDetail {
        MapDetail(
            id: mapID, title: "성수 카페 투어", description: "성수동에서 하루를 보내기 좋은 카페들을 모았어요.",
            imageURL: nil, ownerName: "모아", type: .community, role: .none, tags: ["카페", "데이트", "성수"],
            memberCount: 128, placeCount: 5, joined: false, personal: false, inviteCode: nil
        )
    }

    func fetchPlaces(mapID: Int64) async throws -> [MapPlace] {
        (1...5).map { index in
            MapPlace(
                id: Int64(index), name: "커피나무 \(index)호점", address: "서울 성동구 성수이로 \(index)",
                latitude: 37.5445 + Double(index) * 0.001, longitude: 127.0557 + Double(index) * 0.001, photoURL: nil
            )
        }
    }

    func joinMap(mapID: Int64) async throws {}
    func leaveMap(mapID: Int64) async throws {}
    func deleteMap(mapID: Int64) async throws {}
    func setPlaceLiked(placeID: Int64, liked: Bool) async throws -> PlaceLike {
        PlaceLike(liked: liked, likeCount: liked ? 1 : 0)
    }
}

#Preview {
    NavigationStack {
        MapIntroView(
            viewModel: MapIntroViewModel(mapID: 1, repository: PreviewMapDetailRepository()),
            onPreview: { _, _ in },
            onJoined: { _, _ in }
        )
    }
}
#endif
