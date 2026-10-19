import SwiftUI
import UniformTypeIdentifiers

struct CollectionView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    let viewModel: CollectionViewModel
    let onHome: () -> Void
    var onCreateMap: () -> Void = {}
    var onImportPlaces: (PlaceImportSource) -> Void = { _ in }
    var onMapClick: (MyMap) -> Void = { _ in }
    var onEditMap: (MapDetail) -> Void = { _ in }
    @State private var showsInviteDialog = false
    /// 커뮤니티/프라이빗 선택 표시가 고른 탭으로 미끄러져 가게 한다.
    @Namespace private var tabSelectionSpace
    /// 끌고 있는 지도. 놓거나 다른 곳에 떨어뜨리면 비운다.
    @State private var draggingMapID: Int64?
    /// 핸들로 끄는 카드가 제자리에서 벗어난 거리. 한 칸을 넘으면 옮기고 그만큼 덜어 낸다.
    @State private var handleDragOffset: CGFloat = 0
    /// 카드 한 칸의 높이(간격 포함). 핸들로 끌 때 몇 칸 지났는지 셈한다.
    @State private var cardHeight: CGFloat = 0
    /// 지금까지 옮긴 칸 수만큼의 거리. 손가락이 간 거리에서 빼야 카드가 손가락을 따라간다.
    @State private var consumedDrag: CGFloat = 0
    private static let cardSpacing: CGFloat = 8
    /// 이웃과 자리를 바꾸는 지점(한 칸 대비). 0.5 보다 커야 바꾼 직후 되돌아가지 않는다.
    private static let swapThreshold: CGFloat = 0.6

    private var editing: CollectionEditing? { viewModel.uiState.editing }

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
            // 핸들로 끄는 동안 목록이 같이 움직이지 않게 한다.
            .scrollDisabled(draggingMapID != nil && handleDragOffset != 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let editing { editBar(editing) }
        }
        .overlay { editDialog }
        .moaSnackbar(notice)
        .background { MoaMapPrimitiveColors.tabBackground.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task { viewModel.refresh() }
        .onChange(of: viewModel.uiState.mapToEdit) { _, map in
            guard let map else { return }
            viewModel.consumeMapToEdit()
            onEditMap(map)
        }
        .fullScreenCover(isPresented: $showsInviteDialog) {
            if case .editing(let editing) = viewModel.uiState.join {
                JoinMapDialog(
                    state: editing,
                    onCodeChange: viewModel.updateInviteCode,
                    onSubmit: viewModel.join,
                    onDismiss: viewModel.closeJoinDialog
                )
                .presentationBackground(.clear)
            }
        }
        // 참여 성공으로 닫힐 때도 열 때처럼 애니메이션 없이 닫는다.
        .onChange(of: viewModel.uiState.join == .hidden) { _, hidden in
            withoutAnimation { showsInviteDialog = !hidden }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            MoaMapTopBarLogo {
                // 진행 중인 요청이 끝나면 이 탭에 화면을 띄운다. 그동안은 떠나지 않는다.
                guard editing?.processing != true else { return }
                viewModel.finishEditing()
                onHome()
            }
                .accessibilityLabel("탐색 탭으로 이동")
            Spacer(minLength: 4)
            Button {
                viewModel.openJoinDialog()
            } label: {
                HStack(spacing: 2) {
                    icon("key", size: 24)
                    Text("초대 코드").moaTextStyle(typography.button2)
                }
                .frame(minHeight: 44)
            }
            Button(action: onCreateMap) {
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
                        .background {
                            if selected {
                                Capsule()
                                    .fill(MoaMapPrimitiveColors.yellow100)
                                    .matchedGeometryEffect(id: "selection", in: tabSelectionSpace)
                            }
                        }
                }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
        // 탭 바 안에서만 움직인다. 아래 지도 목록이 바뀌는 것까지 애니메이션되면 안 된다.
        .animation(.easeOut(duration: 0.25), value: viewModel.uiState.selectedTab)
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
            } else {
                VStack(alignment: .trailing, spacing: 12) {
                    editToggle
                    if viewModel.uiState.selectedTab == .community {
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
        }
    }

    private var editToggle: some View {
        Button(editing == nil ? "편집" : "완료") {
            if editing == nil { viewModel.startEditing() } else { viewModel.finishEditing() }
        }
        .moaTextStyle(typography.button1)
        .foregroundStyle(colors.textNormal)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .disabled(editing?.processing == true)
        // 위 탭과의 간격은 시안의 20 을 지키고, 커진 터치 영역만큼 목록 쪽으로 당긴다.
        .padding(.vertical, -11)
    }

    private func mapList(_ maps: [MyMap], showsMembers: Bool) -> some View {
        LazyVStack(spacing: Self.cardSpacing) {
            ForEach(maps) { map in
                let card = Button {
                    if editing == nil { onMapClick(map) } else { viewModel.toggleSelection(mapID: map.id) }
                } label: {
                    CollectionMapCard(
                        map: map, showsMembers: showsMembers,
                        selected: editing.map { $0.selectedIDs.contains(map.id) },
                        showsDragHandle: editing != nil
                    )
                }
                .buttonStyle(.plain)
                if editing == nil {
                    card
                } else {
                    // 핸들은 누르자마자, 카드는 길게 눌러 끈다. 지나가는 자리마다 순서가 바뀌고 저장은 편집을 끝낼 때 한다.
                    let handleDragging = draggingMapID == map.id && handleDragOffset != 0
                    card
                        .overlay(alignment: .leading) { dragHandleArea(map: map) }
                        .offset(y: draggingMapID == map.id ? handleDragOffset : 0)
                        .zIndex(draggingMapID == map.id ? 1 : 0)
                        .scaleEffect(handleDragging ? 1.02 : 1)
                        .shadow(color: .black.opacity(handleDragging ? 0.12 : 0), radius: 8)
                        // 끄는 카드는 손가락을 바로 따라가야 한다. 순서가 바뀔 때의 애니메이션은 나머지 카드에만 건다.
                        .transaction { if draggingMapID == map.id { $0.animation = nil } }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
                        .onDrag {
                            draggingMapID = map.id
                            return NSItemProvider(object: String(map.id) as NSString)
                        }
                        .onDrop(of: [.text], delegate: MapReorderDropDelegate(
                            targetID: map.id, draggingMapID: $draggingMapID,
                            onMove: { viewModel.moveMap($0, to: $1) }
                        ))
                }
            }
        }
        .animation(.default, value: maps.map(\.id))
    }

    /// 카드 왼쪽 두 줄 핸들 자리. 누른 채 위아래로 끌면 이웃 카드 쪽으로 충분히 넘어갈 때마다 자리를 바꾼다.
    private func dragHandleArea(map: MyMap) -> some View {
        Color.clear
            .frame(width: 48)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                // 핸들은 카드와 함께 움직인다. 카드 기준으로 재면 움직일 때마다 거리가 흔들려 화면 기준으로 잰다.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if draggingMapID != map.id {
                            draggingMapID = map.id
                            consumedDrag = 0
                        }
                        handleDragOffset = value.translation.height - consumedDrag
                        let step = cardHeight + Self.cardSpacing
                        // 그릴 때의 목록이 아니라 지금 목록을 본다. 빠르게 끌면 다시 그리기 전에 또 불려 이미 지나친 이웃으로 되돌린다.
                        // 프라이빗 탭은 나만의 지도와 나머지를 따로 보여 주므로 같은 묶음만 이웃으로 본다.
                        guard step > Self.cardSpacing, case .loaded(let current) = viewModel.uiState.currentMaps else { return }
                        let maps = current.filter { $0.personal == map.personal }
                        guard let index = maps.firstIndex(where: { $0.id == map.id }) else { return }
                        // 반 칸보다 더 넘어가야 바꾼다. 경계가 같으면 손떨림에도 자리가 계속 오간다.
                        let threshold = step * Self.swapThreshold
                        if handleDragOffset > threshold, index + 1 < maps.count,
                           viewModel.moveMap(map.id, to: maps[index + 1].id) {
                            consumedDrag += step
                        } else if handleDragOffset < -threshold, index > 0,
                                  viewModel.moveMap(map.id, to: maps[index - 1].id) {
                            consumedDrag -= step
                        }
                        handleDragOffset = value.translation.height - consumedDrag
                    }
                    .onEnded { _ in
                        withAnimation(.default) {
                            draggingMapID = nil
                            handleDragOffset = 0
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    /// 편집 중에는 하단 탭 대신 띄운다.
    private func editBar(_ editing: CollectionEditing) -> some View {
        HStack(spacing: 16) {
            Text("\(editing.selectedIDs.count)개 선택됨")
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
            Spacer(minLength: 0)
            if editing.processing {
                ProgressView()
            }
            if editing.selectedIDs.count == 1 {
                Button(action: viewModel.requestEditInfo) {
                    Text("정보 수정")
                        .moaTextStyle(typography.button2)
                        .foregroundStyle(colors.textWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(colors.primary, in: Capsule())
                }
                .disabled(!editing.canEditInfo)
            }
            Button(action: viewModel.requestLeave) {
                Text("나가기")
                    .moaTextStyle(typography.button2)
                    .foregroundStyle(editing.selectedIDs.isEmpty ? colors.textAssistive : colors.statusAlert)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!editing.canLeave)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding + 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background {
            MoaMapPrimitiveColors.white
                .shadow(color: .black.opacity(0.04), radius: 4)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder private var editDialog: some View {
        switch viewModel.uiState.editDialog {
        case .ownerCannotLeave:
            OwnerCannotLeaveNotice(onDismiss: viewModel.dismissEditDialog)
        case .confirmLeave(let count, let outcome):
            MoaMapConfirmDialog(
                title: "\(count)개의 지도",
                titleSuffix: "에서 나가시겠습니까?",
                message: outcome.confirmMessage,
                confirmText: "나가기",
                onConfirm: viewModel.confirmLeave,
                onDismiss: viewModel.dismissEditDialog
            )
        case nil:
            EmptyView()
        }
    }

    private var notice: Binding<String?> {
        Binding(
            get: { viewModel.uiState.notice },
            set: { if $0 == nil { viewModel.consumeNotice() } }
        )
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
            ImportActionCard(
                iconName: "instagram-logo", title: "인스타그램", subtitle: "장소 찾기",
                background: Color(argb: 0xFFFFF5FB), titleColor: Color(argb: 0xFFAF0069)
            ) { onImportPlaces(.instagram) }
            ImportActionCard(
                iconName: "map", iconTint: colors.secondary, title: "외부 지도", subtitle: "불러오기",
                background: MoaMapPrimitiveColors.yellow50, titleColor: MoaMapPrimitiveColors.yellow800
            ) { onImportPlaces(.mapShare) }
        }
    }

    private func withoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    private func icon(_ name: String, size: CGFloat) -> some View {
        Image("Icons/\(name)").renderingMode(.template).resizable()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// 끌고 있는 카드가 다른 카드 위에 오면 그 자리로 옮긴다.
private struct MapReorderDropDelegate: DropDelegate {
    let targetID: Int64
    @Binding var draggingMapID: Int64?
    let onMove: (_ mapID: Int64, _ targetID: Int64) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingMapID, draggingMapID != targetID else { return }
        onMove(draggingMapID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingMapID = nil
        return true
    }
}

/// 방장인 지도를 골라 나가려 할 때 띄운다. 버튼 없이 바깥을 누르거나 잠시 뒤에 닫힌다.
private struct OwnerCannotLeaveNotice: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("방장은 지도를 나갈 수 없습니다.")
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .accessibilityAddTraits(.isHeader)
                Text("방장인 지도를 빼고 다시 골라주세요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAlternative)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(width: 300)
            .background(colors.backgroundSecondary, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 2) }
            .shadow(color: .black.opacity(0.08), radius: 30, y: 4)
            .onTapGesture(perform: onDismiss)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape, onDismiss)
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { onDismiss() }
        }
    }
}

#if DEBUG
@MainActor
final class PreviewCollectionRepository: CollectionRepository {
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        (1...3).map { (index: Int) -> MyMap in
            let isPersonal = index == 1 && type == .private
            let title = isPersonal ? "나만의 지도" : "서울 팝업스토어 맵"
            return MyMap(
                id: Int64(index),
                title: title,
                imageURL: nil,
                memberCount: 24,
                placeCount: 116,
                official: false,
                personal: isPersonal
            )
        }
    }

    func updateMapOrder(type: CollectionMapType, mapIDs: [Int64]) async throws {}

    func joinByInviteCode(_ inviteCode: String) async throws {}

    func uploadCoverImage(_ image: UploadImage) async throws -> String { "" }

    func createMap(_ newMap: NewMap) async throws -> CreatedMap { CreatedMap(id: 1, inviteCode: nil) }

    func updateMap(mapID: Int64, _ update: MapUpdate) async throws {}
}

#Preview {
    CollectionView(viewModel: CollectionViewModel(repository: PreviewCollectionRepository(), mapRepository: PreviewMapDetailRepository()), onHome: {})
}
#endif
