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
    @State private var memberViewModel: MemberViewModel
    @State private var activityViewModel: MapActivityViewModel
    @State private var pendingViewModel: PendingRequestViewModel
    @State private var postListViewModel: MapPostListViewModel
    @State private var postCalendarViewModel: MapPostCalendarViewModel
    @State private var postCreateViewModel: MapPostCreateViewModel
    @State private var postDetailViewModel: MapPostDetailViewModel
    private let makeEditMap: (MapDetail) -> EditMapViewModel
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
        _memberViewModel = State(initialValue: viewModels.member)
        _activityViewModel = State(initialValue: viewModels.activity)
        _pendingViewModel = State(initialValue: viewModels.pending)
        _postListViewModel = State(initialValue: viewModels.posts)
        _postCalendarViewModel = State(initialValue: viewModels.postCalendar)
        _postCreateViewModel = State(initialValue: viewModels.postCreate)
        _postDetailViewModel = State(initialValue: viewModels.postDetail)
        makeEditMap = viewModels.makeEditMap
        self.locationProvider = locationProvider
        self.initialTitle = initialTitle
        self.onBack = onBack
    }

    @State private var selectedTab: MapDetailTab = .places
    @State private var postViewMode: MapPostViewMode = .card
    @State private var postCreateVisible = false
    @State private var viewport: Viewport = .initial(.center(MapCameraDefaults.center), padding: .init())
    /// 초기 카메라는 한 번만 맞춘다. 사용자가 옮긴 카메라가 튀지 않게 한다.
    @State private var cameraSettled = false
    /// 장소가 없는 지도는 현재 위치로 열어야 해서 권한 답을 기다린다.
    @State private var permissionAnswered = false
    @State private var is3D = false
    @State private var currentCamera: CameraState?
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
    @State private var membersVisible = false
    @State private var manageVisible = false
    @State private var infoVisible = false
    @State private var editMapVisible = false
    /// 지도 정보 수정. 열 때마다 새로 만들어 새로 시작한다. 닫는 동안 화면이 비지 않게 닫아도 남긴다.
    @State private var editMapViewModel: EditMapViewModel?
    /// 마지막으로 읽은 지도. 쌓아 둔 화면은 다시 읽다 실패해도 이것으로 그려 비지 않게 한다.
    @State private var lastLoadedMap: MapDetail?
    /// 장소 등록 완료처럼 지도 위에 잠깐 띄우는 안내.
    @State private var notice: String?

    private static let pitch3D: CGFloat = 55
    /// 마커를 맞출 때 가장자리 여백. 위는 탭 바, 아래는 접힌 시트를 피한다. 좌우는 가장자리 묶음 마커가 잘리지 않게 둔다.
    private var fitPadding: SwiftUI.EdgeInsets {
        let side = PlaceFacepileMarker.maxWidth / 2 + 8
        return SwiftUI.EdgeInsets(top: 80, leading: side, bottom: sheetCollapsedHeight + 40, trailing: side)
    }

    var body: some View {
        observingChildren(screen)
            .task {
                if viewModel.uiState.map == .loading, viewModel.loadTask == nil { viewModel.retry() }
                if locationProvider.authorization == .notDetermined {
                    _ = await locationProvider.requestAuthorization()
                }
                permissionAnswered = true
                settleCamera()
            }
            .sheet(isPresented: clusterSheetPresented) {
                ClusterPlacesSheet(
                    places: expandedClusterPlaces,
                    showsReactions: !viewModel.uiState.isOfficial,
                    onPlaceClick: selectPlace,
                    onLikeClick: { viewModel.toggleLike(placeID: $0) }
                )
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

    /// 상단바·지도와 그 위에 겹치는 화면들.
    private var screen: some View {
        VStack(spacing: 0) {
            MapDetailTopBar(
                title: title,
                action: viewModel.uiState.map.map?.topBarAction ?? .none,
                showsMenu: viewModel.uiState.showsMenu,
                actionEnabled: !viewModel.uiState.actionInProgress,
                onBack: { onBack(viewModel.uiState.joinedHere) },
                onAction: {
                    // 메뉴가 없는 공식지도의 나가기도 같은 확인을 거친다.
                    if viewModel.uiState.canJoin { viewModel.join() } else { leaveDialogVisible = true }
                },
                onMenu: { withAnimation(.dropdownMenu) { menuVisible = true } }
            )
            ZStack(alignment: .top) {
                // 로그 탭에 가도 지도를 내리지 않는다. 다시 만들면 보던 카메라 자리를 잃는다.
                placesContent
                    .opacity(selectedTab == .places ? 1 : 0)
                    .allowsHitTesting(selectedTab == .places)
                    .accessibilityHidden(selectedTab != .places)
                if selectedTab == .logs {
                    // 보기를 바꿔도 카드 목록의 정렬·받은 페이지는 ViewModel 에 남는다.
                    Group {
                        switch postViewMode {
                        case .card:
                            MapPostsView(
                                viewModel: postListViewModel,
                                onViewModeSelect: { postViewMode = $0 },
                                onPostClick: postDetailViewModel.open
                            )
                        case .calendar:
                            MapPostCalendarView(
                                viewModel: postCalendarViewModel,
                                onViewModeSelect: { postViewMode = $0 },
                                onPostClick: postDetailViewModel.open
                            )
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // 장소를 더할 수 있는 지도와 같은 기준이다. 서버도 멤버만 받는다.
                        if viewModel.uiState.canAddPlace {
                            WritePostButton {
                                // 닫아도 ViewModel 은 살아남는다. 지우지 않으면 쓰다 만 글이 남는다.
                                postCreateViewModel.reset()
                                postCreateVisible = true
                            }
                            .padding(20)
                        }
                    }
                }
                if viewModel.uiState.showsLogTab {
                    MapDetailTabBar(selection: selectedTab) { selectedTab = $0 }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }
            }
        }
        // 뒤에 둔 것이 위에 그려진다.
        .overlay { overlays }
        .moaSnackbar($notice)
        .background(colors.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
        // 지도 위에 겹치지 않고 내비게이션에 쌓는다. 가장자리를 쓸어 넘기면 지도 상세로 돌아와야 한다.
        .navigationDestination(isPresented: $membersVisible) {
            if let map = subScreenMap {
                MemberView(
                    viewModel: memberViewModel,
                    roleDisplay: map.memberRoleDisplay,
                    canGrantRole: map.canGrantRole,
                    onBack: { membersVisible = false }
                )
            }
        }
        .navigationDestination(isPresented: $manageVisible) {
            if let map = subScreenMap {
                MapManageView(
                    activityViewModel: activityViewModel,
                    pendingViewModel: pendingViewModel,
                    canReviewRequests: map.canReviewRequests,
                    onBack: { manageVisible = false }
                )
            }
        }
        .navigationDestination(isPresented: $infoVisible) {
            if let map = subScreenMap {
                MapInfoView(
                    map: map,
                    onBack: { infoVisible = false },
                    onEdit: {
                        editMapViewModel = makeEditMap(map)
                        editMapVisible = true
                    }
                )
                // 수정에서 쓸어 넘기면 지도 정보로 돌아온다.
                .navigationDestination(isPresented: $editMapVisible) {
                    if let editMapViewModel {
                        EditMapView(
                            viewModel: editMapViewModel,
                            onBack: { editMapVisible = false },
                            onSaved: {
                                editMapVisible = false
                                // 지도 정보와 상단 제목이 고친 값을 보여야 한다.
                                viewModel.refresh()
                            }
                        )
                    }
                }
            }
        }
    }

    private var subScreenMap: MapDetail? { viewModel.uiState.map.map ?? lastLoadedMap }

    /// 지도 상세 위에 겹치는 시트·화면·팝업.
    @ViewBuilder
    private var overlays: some View {
        ZStack {
            // 검색으로 목록에서 빠진 장소라도, 마커로 눌러 열어 둔 상세는 닫히면 안 된다.
            let selectedPlace = viewModel.uiState.places.first(where: { $0.id == selectedPlaceID })

            // 펼치면 상단바까지 덮는다. 장소 상세가 떠 있는 동안은 감춘다. 두 시트가 겹쳐 보이면 안 된다.
            // 빼지 않고 감춰야 돌아왔을 때 보던 목록 위치가 남는다.
            if selectedTab == .places {
                placeSheet
                    .opacity(selectedPlace == nil ? 1 : 0)
                    .allowsHitTesting(selectedPlace == nil)
                    .accessibilityHidden(selectedPlace != nil)
            }

            if let place = selectedPlace {
                // 장소마다 입력 중인 글과 사진을 새로 시작한다.
                placeDetail(place).id(place.id)
            }

            if postCreateVisible {
                MapPostCreateView(
                    viewModel: postCreateViewModel,
                    places: viewModel.uiState.places,
                    onClose: { postCreateVisible = false }
                )
            }

            if let post = postDetailViewModel.uiState.post {
                MapPostDetailView(
                    viewModel: postDetailViewModel,
                    post: post,
                    dateLabel: postCalendarViewModel.dateLabel(of: post.createdAt),
                    // 게시물을 쓸 수 있는 사람과 같은 기준이다. 서버도 멤버만 받는다.
                    canComment: viewModel.uiState.canAddPlace
                )
                // 게시물마다 입력 중인 댓글을 새로 시작한다.
                .id(post.id)
            }

            // 지도를 아직 못 읽었으면 열지 않는다. 버튼 글씨가 지도 정보에 달려 있다.
            if addPlaceVisible, let map = viewModel.uiState.map.map {
                AddPlaceView(viewModel: addPlaceViewModel, map: map, onClose: { addPlaceVisible = false })
            }

            // 나가서 참여가 풀리면 메뉴도 함께 닫힌다.
            if menuVisible && viewModel.uiState.showsMenu { menu.transition(.dropdownMenu) }

            // 나가기로 자격을 잃으면 같이 닫힌다.
            if inviteCodeVisible, let code = viewModel.uiState.inviteCode {
                MapInviteCodeDialog(mapName: title, inviteCode: code) { inviteCodeVisible = false }
            }

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
    }

    /// 다른 ViewModel 의 신호를 받아 지도 상세를 맞춘다.
    private func observingChildren(_ content: some View) -> some View {
        content
            .onChange(of: viewModel.uiState.map) {
                if let map = viewModel.uiState.map.map { lastLoadedMap = map }
                settleCamera()
            }
            .onChange(of: viewModel.uiState.errorMessage) { _, message in
                if let message { alert = .error(message) }
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
            // 등록 중에 화면을 닫아도 결과를 받도록 부모가 지켜본다.
            .onChange(of: addPlaceViewModel.uiState.addedMessage) { _, message in
                guard let message else { return }
                addPlaceVisible = false
                notice = message
                // 장소 수가 늘었다. 상단과 시트 제목이 옛 값을 들고 있으면 안 된다.
                viewModel.refresh()
            }
            .onChange(of: postCreateViewModel.uiState.postedCount) {
                // 새 글이 맨 위(최신순)나 맨 아래(등록순)에 붙도록 첫 페이지부터 다시 읽는다.
                postCreateVisible = false
                postListViewModel.retry()
                postCalendarViewModel.refresh()
            }
            .onChange(of: pendingViewModel.uiState.approvedCount) {
                // 수락한 장소는 지도에 새로 떠야 한다.
                viewModel.refresh()
            }
            .onChange(of: viewModel.uiState.showsLogTab) { _, shows in
                if !shows { selectedTab = .places }
            }
            .onChange(of: viewModel.uiState.left) { _, left in
                // 나간 뒤에는 멤버가 아니라 소개 화면이 남아 있으면 그쪽으로 돌아간다.
                if left { onBack(false) }
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
                showsMembers: viewModel.uiState.showsMembersMenu,
                showsInfo: viewModel.uiState.showsInfoMenu,
                showsInviteCode: viewModel.uiState.inviteCode != nil,
                canLeave: viewModel.uiState.canLeave,
                onMembers: {
                    menuVisible = false
                    membersVisible = true
                },
                onManage: {
                    menuVisible = false
                    manageVisible = true
                },
                onInfo: {
                    menuVisible = false
                    infoVisible = true
                },
                onInviteCode: {
                    menuVisible = false
                    inviteCodeVisible = true
                },
                onLeave: {
                    menuVisible = false
                    leaveDialogVisible = true
                }
            )
            // 시안은 상단바 아래쪽에 살짝 걸쳐 띄운다.
            .padding(.top, 45)
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
            onInstagram: { if let url = place.instagramURL { openURL(url) } },
            onViewMap: { openKakaoMap(place) },
            onAddToPersonalMap: { personalMapViewModel.add() },
            onLike: { viewModel.toggleLike(placeID: place.id) },
            // 시트 높이가 정해진 뒤에야 장소를 가리지 않는 자리를 안다.
            onCollapsedHeightSettle: { height in moveCamera(to: place, bottomPadding: height) }
        )
    }

    /// 묶음 목록에서 골랐으면 그 목록은 닫는다.
    private func selectPlace(_ placeID: Int64) {
        expandedClusterIDs = []
        selectedPlaceID = placeID
    }

    /// 장소를 상세 시트에 가리지 않는 위쪽 가운데로 옮긴다.
    private func moveCamera(to place: MapPlace, bottomPadding: CGFloat) {
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        withViewportAnimation(.easeOut(duration: 0.6)) {
            viewport = .camera(center: center, zoom: zoomKeepingCloser).padding(.bottom, bottomPadding)
        }
    }

    private var currentZoom: Double? { currentCamera.map { Double($0.zoom) } }

    /// 이미 더 확대해 봤으면 그 줌을 뺏지 않는다.
    private var zoomKeepingCloser: Double {
        max(currentZoom ?? MapCameraDefaults.zoom, MapCameraDefaults.zoom)
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

    /// 묶인 장소가 보이는 칸에 꽉 차게 확대한다. 끝까지 확대해도 안 갈라지면 목록으로 연다.
    private func tapCluster(_ cluster: MarkerCluster) {
        guard cluster.splitsByZoom, !MarkerClustering.isZoomMaxed(currentZoom) else {
            expandedClusterIDs = cluster.members.map(\.id)
            return
        }
        let coordinates = cluster.members.map(\.coordinate)
        // 기울기·방향을 넘기지 않으면 3D 로 보던 지도가 펴진다.
        withViewportAnimation(.easeOut(duration: 0.6)) {
            viewport = .overview(
                geometry: MultiPoint(coordinates),
                bearing: CGFloat(currentCamera?.bearing ?? 0),
                pitch: currentCamera?.pitch ?? 0,
                geometryPadding: fitPadding,
                maxZoom: MarkerClustering.maxZoom
            )
        }
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
            // 들어올 때 권한을 묻는다. 허용되는 순간부터 내 위치가 보인다.
            showsMyLocation: locationProvider.authorization == .granted,
            onCameraChanged: { currentCamera = $0 },
            onMarkerTap: selectPlace,
            onClusterTap: tapCluster
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
            withViewportAnimation(.easeOut(duration: 0.6)) {
                viewport = .camera(center: point, zoom: zoomKeepingCloser)
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

enum MapDetailAlert: Equatable {
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
    // 메뉴로 여는 화면은 내비게이션에 쌓는다.
    NavigationStack {
        MapDetailView(
            viewModels: .preview(mapID: 1),
            locationProvider: PreviewLocationProvider(),
            onBack: { _ in }
        )
    }
}
#endif
