import CoreLocation
import MapboxMaps
import SwiftUI

struct MapDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.openURL) private var openURL

    @State private var viewModel: MapDetailViewModel
    @State private var personalMapViewModel: PersonalMapAddViewModel
    @State private var reviewViewModel: PlaceReviewViewModel
    @State private var addPlaceViewModel: AddPlaceViewModel
    private let locationProvider: any LocationProvider
    /// 서버 응답이 오기 전 상단바를 채우는 제목.
    private let initialTitle: String
    /// 이 화면에서 참여했는지를 함께 넘긴다. 어디까지 되돌릴지는 내비게이션이 정한다.
    private let onBack: (_ joinedHere: Bool) -> Void

    init(
        viewModels: MapDetailViewModels,
        locationProvider: any LocationProvider,
        initialTitle: String = "",
        onBack: @escaping (_ joinedHere: Bool) -> Void
    ) {
        _viewModel = State(initialValue: viewModels.main)
        _personalMapViewModel = State(initialValue: viewModels.personalMap)
        _reviewViewModel = State(initialValue: viewModels.review)
        _addPlaceViewModel = State(initialValue: viewModels.addPlace)
        self.locationProvider = locationProvider
        self.initialTitle = initialTitle
        self.onBack = onBack
    }

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
    @State private var menuVisible = false
    @State private var inviteCodeVisible = false
    @State private var leaveDialogVisible = false
    @State private var searchQuery = ""
    @State private var selectedCategory: PlaceCategoryFilter = .all
    @State private var sheetExpanded = false
    @State private var sheetCollapsedHeight = MapDetailPlaceSheet.defaultCollapsedHeight
    /// 펼친 묶음 마커의 장소. 비어 있으면 목록을 띄우지 않는다.
    @State private var expandedClusterIDs: [Int64] = []
    @State private var selectedPlaceID: Int64?
    @State private var addPlaceVisible = false
    /// 장소 등록 완료처럼 지도 위에 잠깐 띄우는 안내.
    @State private var notice: String?

    private static let pitch3D: CGFloat = 55
    /// 마커를 맞출 때 가장자리 여백. 위는 탭 바, 아래는 접힌 시트를 피한다.
    private var fitPadding: SwiftUI.EdgeInsets {
        SwiftUI.EdgeInsets(top: 80, leading: 40, bottom: sheetCollapsedHeight + 40, trailing: 40)
    }

    var body: some View {
        VStack(spacing: 0) {
            MapDetailTopBar(
                title: title,
                roleBadge: viewModel.uiState.roleBadge,
                action: viewModel.uiState.map.map?.topBarAction ?? .none,
                showsMenu: viewModel.uiState.showsMenu,
                inviteCode: viewModel.uiState.inviteCode,
                actionEnabled: !viewModel.uiState.actionInProgress,
                onBack: { onBack(viewModel.uiState.joinedHere) },
                onAction: {
                    // 메뉴가 없는 공식지도의 나가기도 같은 확인을 거친다.
                    if viewModel.uiState.canJoin { viewModel.join() } else { leaveDialogVisible = true }
                },
                onInviteCode: { inviteCodeVisible = true },
                onMenu: { menuVisible = true }
            )
            ZStack(alignment: .top) {
                // 로그 탭에 가도 지도를 내리지 않는다. 다시 만들면 보던 카메라 자리를 잃는다.
                placesContent
                    .opacity(selectedTab == .places ? 1 : 0)
                    .allowsHitTesting(selectedTab == .places)
                    .accessibilityHidden(selectedTab != .places)
                if selectedTab == .logs {
                    // TODO: 로그 탭(게시물 목록·달력)을 옮긴다.
                    colors.backgroundSecondary
                }
                // 공식지도는 로그 탭이 없다.
                if !viewModel.uiState.isOfficial {
                    MapDetailTabBar(selection: selectedTab) { selectedTab = $0 }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
            }
        }
        .overlay {
            // 펼치면 상단바까지 덮는다.
            if selectedTab == .places { placeSheet }
        }
        .overlay {
            // 검색으로 목록에서 빠진 장소라도, 마커로 눌러 열어 둔 상세는 닫히면 안 된다.
            if let place = viewModel.uiState.places.first(where: { $0.id == selectedPlaceID }) {
                // 장소마다 입력 중인 글과 사진을 새로 시작한다.
                placeDetail(place).id(place.id)
            }
        }
        .overlay {
            // 지도를 아직 못 읽었으면 열지 않는다. 버튼 글씨가 지도 정보에 달려 있다.
            if addPlaceVisible, let map = viewModel.uiState.map.map {
                AddPlaceView(
                    viewModel: addPlaceViewModel,
                    map: map,
                    onClose: { addPlaceVisible = false },
                    onAdded: { message in
                        addPlaceVisible = false
                        notice = message
                        // 장소 수가 늘었다. 상단과 시트 제목이 옛 값을 들고 있으면 안 된다.
                        viewModel.refresh()
                    }
                )
            }
        }
        .overlay(alignment: .topTrailing) {
            // 나가서 참여가 풀리면 메뉴도 함께 닫힌다.
            if menuVisible && viewModel.uiState.showsMenu { menu }
        }
        .overlay {
            // 나가기로 자격을 잃으면 같이 닫힌다.
            if inviteCodeVisible, let code = viewModel.uiState.inviteCode {
                MapInviteCodeDialog(mapName: title, inviteCode: code) { inviteCodeVisible = false }
            }
        }
        .overlay {
            // 나갈 수 없는 상태가 되면 같이 닫힌다.
            if leaveDialogVisible, let outcome = viewModel.uiState.leaveOutcome {
                MoaMapConfirmDialog(
                    title: title,
                    titleSuffix: "에서 나가시겠습니까?",
                    message: outcome.confirmMessage,
                    onConfirm: {
                        leaveDialogVisible = false
                        viewModel.leave()
                    },
                    onDismiss: { leaveDialogVisible = false }
                )
            }
        }
        .moaSnackbar($notice)
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
        .sheet(isPresented: clusterSheetPresented) {
            ClusterPlacesSheet(
                places: expandedClusterPlaces,
                showsReactions: !viewModel.uiState.isOfficial,
                onPlaceClick: selectPlace,
                onLikeClick: { viewModel.toggleLike(placeID: $0) }
            )
        }
        .onChange(of: selectedPlaceID) { _, placeID in
            // 나만의 지도 추가 안내와 댓글은 장소마다 새로 시작한다. 공식지도에는 댓글이 없다.
            if let placeID {
                personalMapViewModel.open(placeID: placeID)
                if !viewModel.uiState.isOfficial { reviewViewModel.open(placeID: placeID) }
            } else {
                personalMapViewModel.close()
                reviewViewModel.close()
            }
        }
        .onChange(of: reviewViewModel.uiState.submittedCount + reviewViewModel.uiState.deletedCount) {
            // 댓글 수가 달라졌다. 목록이 옛 값을 들고 있으면 안 된다.
            viewModel.refresh()
        }
        .onChange(of: viewModel.uiState.isOfficial) { _, official in
            if official { selectedTab = .places }
        }
        .onChange(of: viewModel.uiState.left) { _, left in
            // 나간 뒤에는 멤버가 아니라 소개 화면이 남아 있으면 그쪽으로 돌아간다.
            if left { onBack(false) }
        }
        .alert(alert?.title ?? "", isPresented: showsAlert, presenting: alert) { alert in
            switch alert {
            case .locationDenied:
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("취소", role: .cancel) {}
            case .locationUnavailable, .error:
                Button("확인", role: .cancel) {}
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }

    private var title: String { viewModel.uiState.map.map?.title ?? initialTitle }

    private var menu: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { menuVisible = false }
                .accessibilityHidden(true)
            MapDetailMenu(
                canLeave: viewModel.uiState.canLeave,
                onMembers: { menuVisible = false },
                onManage: { menuVisible = false },
                onLeave: {
                    menuVisible = false
                    leaveDialogVisible = true
                }
            )
            .padding(.top, 58)
            .padding(.trailing, MoaMapDimens.screenHorizontalPadding)
            .accessibilityAction(.escape) { menuVisible = false }
        }
    }

    private var placeSheet: some View {
        GeometryReader { proxy in
            MapDetailPlaceSheet(
                places: visiblePlaces,
                placeCount: viewModel.uiState.map.map?.placeCount,
                official: viewModel.uiState.isOfficial,
                categoryFilters: PlaceCategoryFilter.available(in: viewModel.uiState.places),
                selectedCategory: selectedCategory,
                searchQuery: $searchQuery,
                expanded: $sheetExpanded,
                collapsedHeight: $sheetCollapsedHeight,
                expandedHeight: proxy.size.height + proxy.safeAreaInsets.top - MapDetailPlaceSheet.expandedTopInset,
                onCategorySelect: { selectedCategory = $0 },
                onPlaceClick: selectPlace,
                onLikeClick: { viewModel.toggleLike(placeID: $0) }
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func placeDetail(_ place: MapPlace) -> some View {
        // 나만의 지도를 보고 있으면 담을 곳이 자기 자신이라 버튼을 뺀다. 지도를 아직 못 읽었으면 띄우지 않는다.
        let personalAction: PersonalMapAction? = if viewModel.uiState.map.map?.personal != false {
            nil
        } else if personalMapViewModel.uiState.placeID != place.id {
            PersonalMapAction()
        } else {
            PersonalMapAction(
                adding: personalMapViewModel.uiState.adding,
                message: personalMapViewModel.uiState.message,
                failed: personalMapViewModel.uiState.failed
            )
        }
        return PlaceDetailView(
            place: place,
            personalMapAction: personalAction,
            reviews: viewModel.uiState.isOfficial ? nil : reviewViewModel,
            // 서버도 같은 기준으로 막는다.
            canWriteReview: viewModel.uiState.canAddPlace,
            onBack: { selectedPlaceID = nil },
            onClose: resetToInitial,
            onExternalLink: { openKakaoMap(place) },
            onAddToPersonalMap: { personalMapViewModel.add() },
            onLike: { viewModel.toggleLike(placeID: place.id) }
        )
    }

    /// 묶음 목록에서 골랐으면 그 목록은 닫는다.
    private func selectPlace(_ placeID: Int64) {
        expandedClusterIDs = []
        selectedPlaceID = placeID
    }

    /// 지도 상세에 처음 들어왔을 때로 되돌린다.
    private func resetToInitial() {
        selectedPlaceID = nil
        selectedTab = .places
        searchQuery = ""
        selectedCategory = .all
        sheetExpanded = false
    }

    /// 앱이 없으면 웹으로 넘어간다.
    private func openKakaoMap(_ place: MapPlace) {
        let web = KakaoMapLink.webURL(kakaoPlaceID: place.kakaoPlaceID, placeName: place.name)
        guard let app = KakaoMapLink.appURL(kakaoPlaceID: place.kakaoPlaceID) else {
            if let web { openURL(web) }
            return
        }
        openURL(app) { accepted in
            if !accepted, let web { openURL(web) }
        }
    }

    private var visiblePlaces: [MapPlace] {
        viewModel.uiState.places.filtered(by: selectedCategory, query: searchQuery)
    }

    private var expandedClusterPlaces: [MapPlace] {
        let byID = Dictionary(viewModel.uiState.places.map { ($0.id, $0) }) { first, _ in first }
        return expandedClusterIDs.compactMap { byID[$0] }
    }

    private var clusterSheetPresented: Binding<Bool> {
        Binding(
            get: { !expandedClusterPlaces.isEmpty },
            set: { if !$0 { expandedClusterIDs = [] } }
        )
    }

    private var placesContent: some View {
        PlaceMarkerMap(
            // 목록과 같은 결과를 지도에도 그린다.
            places: visiblePlaces,
            viewport: $viewport,
            shows3DObjects: is3D,
            ornamentBottomInset: sheetCollapsedHeight,
            onCameraChanged: { currentZoom = $0.zoom },
            onMarkerTap: selectPlace,
            // 좌표가 같은 장소는 확대해도 갈라지지 않아 목록으로 펼친다.
            onClusterTap: { cluster in expandedClusterIDs = cluster.members.map(\.id) }
        )
        .overlay(alignment: .bottom) {
            HStack(alignment: .bottom) {
                MyLocationButton(inProgress: locating, action: moveToMyLocation)
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    MapDimensionToggle(is3D: is3D, onToggle: toggle3D)
                    AddPlaceButton(enabled: viewModel.uiState.canAddPlace) {
                        // 닫아도 ViewModel 은 살아남는다. 지우지 않으면 직전에 등록한 장소의 폼이 보인다.
                        addPlaceViewModel.reset()
                        addPlaceVisible = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, sheetCollapsedHeight + 16)
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
        viewport = .initial(InitialCamera(places: places, deviceLocation: location), padding: fitPadding)
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
        viewModels: .preview(mapID: 1),
        locationProvider: PreviewLocationProvider(),
        onBack: { _ in }
    )
}
#endif
