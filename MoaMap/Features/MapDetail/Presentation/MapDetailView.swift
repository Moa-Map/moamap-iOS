import MapboxMaps
import SwiftUI

struct MapDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.openURL) private var openURL

    let viewModel: MapDetailViewModel
    let locationProvider: any LocationProvider
    /// 서버 응답이 오기 전 상단바를 채우는 제목.
    var initialTitle = ""
    /// 이 화면에서 참여했는지를 함께 넘긴다. 어디까지 되돌릴지는 내비게이션이 정한다.
    let onBack: (_ joinedHere: Bool) -> Void

    @State private var selectedTab: MapDetailTab = .places
    @State private var viewport: Viewport = .initial(.center(MapCameraDefaults.center), padding: .init())
    /// 초기 카메라는 한 번만 맞춘다. 사용자가 옮긴 카메라가 튀지 않게 한다.
    @State private var cameraSettled = false
    /// 장소가 없는 지도는 현재 위치로 열어야 해서 권한 답을 기다린다.
    @State private var permissionAnswered = false
    @State private var is3D = false
    @State private var currentZoom: Double?
    @State private var locating = false
    @State private var alert: MapDetailAlert?

    private static let pitch3D: CGFloat = 55
    /// 마커를 맞출 때 가장자리 여백. 위는 탭 바를 피한다.
    private static let fitPadding = SwiftUI.EdgeInsets(top: 80, leading: 40, bottom: 80, trailing: 40)

    var body: some View {
        VStack(spacing: 0) {
            MapDetailTopBar(
                title: viewModel.uiState.map.map?.title ?? initialTitle,
                roleBadge: viewModel.uiState.roleBadge,
                showsJoin: viewModel.uiState.canJoin,
                joinEnabled: !viewModel.uiState.joining,
                onBack: { onBack(viewModel.uiState.joinedHere) },
                onJoin: { viewModel.join() }
            )
            ZStack(alignment: .top) {
                switch selectedTab {
                case .places: placesContent
                // TODO: 로그 탭(게시물 목록·달력)을 옮긴다.
                case .logs: colors.backgroundSecondary
                }
                MapDetailTabBar(selection: selectedTab) { selectedTab = $0 }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }
        }
        .background(colors.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.uiState.map == .loading, viewModel.loadTask == nil { viewModel.retry() }
            if locationProvider.authorization == .notDetermined {
                _ = await locationProvider.requestAuthorization()
            }
            permissionAnswered = true
            settleCamera()
        }
        .onChange(of: viewModel.uiState.map) { settleCamera() }
        .onChange(of: viewModel.uiState.errorMessage) { _, message in
            if let message { alert = .error(message) }
        }
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

    private var placesContent: some View {
        PlaceMarkerMap(
            places: viewModel.uiState.places,
            viewport: $viewport,
            shows3DObjects: is3D,
            onCameraChanged: { currentZoom = $0.zoom }
        )
        .overlay(alignment: .bottom) {
            HStack(alignment: .bottom) {
                MyLocationButton(inProgress: locating, action: moveToMyLocation)
                Spacer()
                MapDimensionToggle(is3D: is3D, onToggle: toggle3D)
            }
            .padding(.horizontal, 20)
            // 왼쪽 아래 Mapbox 로고를 가리지 않게 띄운다.
            .padding(.bottom, 40)
        }
        .overlay {
            if case .failed(let message) = viewModel.uiState.map {
                CommunityMapsError(message: message) { viewModel.retry() }
                    .padding(24)
                    .background(colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var showsAlert: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { presented in
                guard !presented else { return }
                if case .error = alert { viewModel.consumeErrorMessage() }
                alert = nil
            }
        )
    }

    /// 장소를 현재 위치보다 앞에 둔다. 장소가 없을 때만 권한 답을 기다려 현재 위치를 쓴다.
    private func settleCamera() {
        guard !cameraSettled, viewModel.uiState.map != .loading else { return }
        let places = viewModel.uiState.places
        guard !places.isEmpty || permissionAnswered else { return }
        let location = places.isEmpty ? locationProvider.lastKnownLocation : nil
        viewport = .initial(InitialCamera(places: places, deviceLocation: location), padding: Self.fitPadding)
        cameraSettled = true
    }

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
            // 기울기는 그대로 둔다. 2D 로 보던 지도가 버튼 하나에 기울어지면 안 된다.
            // 이미 더 확대해 봤으면 그 줌을 뺏지 않는다.
            withViewportAnimation(.easeOut(duration: 0.6)) {
                viewport = .camera(center: point, zoom: max(currentZoom ?? MapCameraDefaults.zoom, MapCameraDefaults.zoom))
            }
        }
    }

    private func toggle3D() {
        is3D.toggle()
        withViewportAnimation(.easeInOut(duration: 0.4)) {
            viewport = .camera(pitch: is3D ? Self.pitch3D : 0)
        }
    }
}

private enum MapDetailAlert: Equatable {
    case locationDenied
    case locationUnavailable
    case error(String)

    var title: String {
        switch self {
        case .locationDenied: "위치 권한이 필요해요"
        case .locationUnavailable: "현재 위치를 찾지 못했어요"
        case .error: "요청을 처리하지 못했어요"
        }
    }

    var message: String? {
        switch self {
        case .locationDenied: "설정에서 위치 접근을 허용하면 현재 위치로 이동할 수 있어요."
        case .locationUnavailable: nil
        case .error(let message): message
        }
    }
}

#if DEBUG
@MainActor
private final class PreviewLocationProvider: LocationProvider {
    var authorization: LocationAuthorization = .granted
    var lastKnownLocation: CLLocationCoordinate2D? { MapCameraDefaults.center }
    func requestAuthorization() async -> LocationAuthorization { authorization }
    func currentLocation() async -> CLLocationCoordinate2D? { MapCameraDefaults.center }
}

#Preview {
    MapDetailView(
        viewModel: MapDetailViewModel(mapID: 1, repository: PreviewMapDetailRepository()),
        locationProvider: PreviewLocationProvider(),
        onBack: { _ in }
    )
}
#endif
