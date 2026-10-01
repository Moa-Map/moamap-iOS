import SwiftUI

struct MapIntroView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    let viewModel: MapIntroViewModel
    let onPreview: () -> Void
    let onJoined: () -> Void

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
            if joined { onJoined() }
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
            // TODO: 장소 마커 지도로 바꾼다.
            MoaMapPrimitiveColors.blue50
                .frame(height: 236)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    previewButton.padding(10)
                }
        }
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
                Button(action: onPreview) {
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
        Button(action: onPreview) {
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
}

#Preview {
    NavigationStack {
        MapIntroView(
            viewModel: MapIntroViewModel(mapID: 1, repository: PreviewMapDetailRepository()),
            onPreview: {},
            onJoined: {}
        )
    }
}
#endif
