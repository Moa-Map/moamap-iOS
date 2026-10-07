import MapboxMaps
import SwiftUI

/// 공중화장실 지도. 장소가 없는 특수 공식지도라 지도 상세 대신 이 화면이 열린다.
/// 상단바·참여·나가기는 `OfficialMapScaffold` 가 지도 상세 것을 그대로 쓴다.
struct RestroomMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.openURL) private var openURL

    @State private var viewModel: RestroomMapViewModel
    private let membership: MapDetailViewModel
    private let title: String
    private let locationProvider: any LocationProvider
    private let onBack: (_ joinedHere: Bool) -> Void

    @State private var viewport: Viewport
    @State private var currentZoom: Double?
    @State private var locating = false
    @State private var alert: MapDetailAlert?

    /// 부모가 다시 그려져도 처음 받은 ViewModel 을 쓴다.
    init(
        viewModel: RestroomMapViewModel,
        membership: MapDetailViewModel,
        title: String,
        locationProvider: any LocationProvider,
        onBack: @escaping (_ joinedHere: Bool) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.membership = membership
        self.title = title
        self.locationProvider = locationProvider
        self.onBack = onBack
        _viewport = State(initialValue: .camera(
            center: locationProvider.lastKnownLocation ?? RestroomMapCamera.start, zoom: RestroomMapCamera.zoom
        ))
    }

    var body: some View {
        OfficialMapScaffold(membership: membership, initialTitle: title, onBack: onBack) {
            RestroomMarkersMap(
                restrooms: viewModel.uiState.restrooms,
                selected: viewModel.uiState.selected,
                viewport: $viewport,
                onCameraIdle: { viewModel.onCameraIdle($0) },
                onCameraChanged: { currentZoom = $0.zoom },
                onRestroomTap: { viewModel.selectRestroom(id: $0) },
                onMapTap: { viewModel.clearSelection() },
                // 들어올 때 권한을 묻는다. 허용되면 현재 위치로 카메라가 옮겨지며 다시 그려진다.
                showsMyLocation: locationProvider.authorization == .granted
            )
            .overlay(alignment: .top) {
                if let message = noticeMessage { notice(message) }
            }
            .overlay(alignment: .bottom) {
                // 카드가 뜨면 내 위치 버튼은 카드 위로 올라간다.
                VStack(alignment: .leading, spacing: 16) {
                    MyLocationButton(inProgress: locating, action: moveToMyLocation)
                    if let restroom = viewModel.uiState.selected {
                        RestroomInfoCard(restroom: restroom, detail: viewModel.uiState.detail)
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.bottom, 30)
            }
        }
        .task { await moveToCurrentLocation() }
        .alert(alert?.title ?? "", isPresented: showsAlert, presenting: alert) { alert in
            if alert == .locationDenied {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("취소", role: .cancel) {}
            } else {
                Button("확인", role: .cancel) {}
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }

    private var noticeMessage: String? {
        if viewModel.uiState.loadFailed { return "화장실 정보를 불러오지 못했어요. 지도를 움직이면 다시 불러와요" }
        if viewModel.uiState.truncated { return "화장실이 많아 일부만 보여요. 지도를 확대해 주세요" }
        return nil
    }

    private var showsAlert: Binding<Bool> {
        Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })
    }

    /// 지도 위 안내 한 줄. 상태가 풀릴 때까지 떠 있다.
    private func notice(_ text: String) -> some View {
        Text(text)
            .moaTextStyle(typography.body3)
            .foregroundStyle(MoaMapPrimitiveColors.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MoaMapPrimitiveColors.blue800, in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 16)
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
    }

    /// 가까운 화장실을 찾는 지도라 처음에 현재 위치로 간다. 권한이 없거나 못 찾으면 시작 자리에 머문다.
    private func moveToCurrentLocation() async {
        if locationProvider.authorization == .notDetermined {
            _ = await locationProvider.requestAuthorization()
        }
        guard locationProvider.authorization == .granted,
              let point = await locationProvider.currentLocation() else { return }
        viewport = .camera(center: point, zoom: RestroomMapCamera.zoom)
    }

    /// 지도 상세와 같다. 더 확대해 보고 있었으면 그 줌을 뺏지 않는다.
    private func moveToMyLocation() {
        guard !locating else { return }
        locating = true
        Task {
            defer { locating = false }
            var authorization = locationProvider.authorization
            if authorization == .notDetermined {
                authorization = await locationProvider.requestAuthorization()
            }
            guard authorization == .granted else {
                alert = .locationDenied
                return
            }
            guard let point = await locationProvider.currentLocation() else {
                alert = .locationUnavailable
                return
            }
            withViewportAnimation(.easeOut(duration: 0.6)) {
                viewport = .camera(center: point, zoom: max(currentZoom ?? RestroomMapCamera.zoom, RestroomMapCamera.zoom))
            }
        }
    }
}

#if DEBUG
@MainActor
final class PreviewRestroomRepository: RestroomRepository {
    func fetchRestrooms(in bounds: ViewportBounds) async throws -> RestroomMarkers {
        RestroomMarkers(restrooms: [], truncated: false)
    }
    func fetchRestroom(id: Int64) async throws -> RestroomDetail { throw CancellationError() }
}
#endif
