import MapboxMaps
import SwiftUI

/// 장소 추가. 지도 상세 위를 덮는 한 장이고, 검색, 지도에서 위치 확인, 등록 폼 세 단계가 이 안에서 오간다.
struct AddPlaceView: View {
    @Environment(\.moaColors) private var colors

    let viewModel: AddPlaceViewModel
    let map: MapDetail
    /// 검색 단계에서 뒤로가면 닫는다.
    let onClose: () -> Void

    @State private var showsPhotoPicker = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AddPlaceField?

    private var state: AddPlaceUiState { viewModel.uiState }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(colors.backgroundSecondary)
            // 뒤에 깔린 지도로 터치가 새지 않게 하고, 빈 곳을 누르면 키보드를 내린다.
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .fullScreenCover(isPresented: $showsPhotoPicker) {
                PhotoLibraryPicker(
                    maxSelection: AddPlaceUiState.maxPhotos - state.photos.count,
                    onCancel: { showsPhotoPicker = false },
                    onPicked: { photos in
                        showsPhotoPicker = false
                        for photo in photos { viewModel.addPhoto(data: photo.data, type: photo.type) }
                    }
                )
            }
            .moaSnackbar($errorMessage)
            .onChange(of: state.errorMessage, initial: true) { _, message in
                guard let message else { return }
                errorMessage = message
                viewModel.consumeErrorMessage()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let selected = state.selected, state.isFormStep {
            VStack(spacing: 0) {
                MoaMapTopBar(title: "장소 추가", onBack: viewModel.backToLocation)
                AddPlaceFormContent(
                    name: selected.name,
                    address: selected.displayAddress,
                    photos: state.photos,
                    tags: state.tags,
                    tagInput: state.tagInput,
                    memo: state.memo,
                    focus: $focusedField,
                    onAddPhoto: {
                        focusedField = nil
                        showsPhotoPicker = true
                    },
                    onRemovePhoto: viewModel.removePhoto(at:),
                    onTagInputChange: {
                        viewModel.updateTagInput($0)
                        return viewModel.uiState.tagInput
                    },
                    onTagBackspace: viewModel.removeLastTagIfInputEmpty,
                    onRemoveTag: viewModel.removeTag,
                    onMemoChange: viewModel.updateMemo
                )
                .padding(.top, 16)
                // 입력값은 모두 선택이라 처음부터 누를 수 있다. 비활성은 보내는 중일 때뿐이다.
                PlaceImportButton(text: map.addPlaceButtonLabel, height: 54, enabled: !state.submitting) {
                    viewModel.submit(map: map)
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.bottom, 16)
            }
        } else if let selected = state.selected {
            AddPlaceLocationContent(
                candidate: selected,
                onBack: viewModel.backToSearch,
                onConfirm: viewModel.confirmLocation
            )
        } else {
            VStack(spacing: 0) {
                MoaMapTopBar(title: "장소 검색", onBack: onClose)
                AddPlaceSearchContent(
                    query: state.query,
                    search: state.search,
                    focus: $focusedField,
                    onQueryChange: viewModel.updateQuery,
                    onRetry: viewModel.retrySearch,
                    onSelect: viewModel.select
                )
            }
        }
    }
}

enum AddPlaceField: Hashable {
    case search, tag, memo
}

struct AddPlaceSearchContent: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let query: String
    let search: PlaceSearchState
    let focus: FocusState<AddPlaceField?>.Binding
    let onQueryChange: (String) -> Void
    let onRetry: () -> Void
    let onSelect: (PlaceCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlaceImportHeader(title: "어떤 장소를 추가할까요?", description: "장소나 도로명으로 검색해보세요")
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
            searchField
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
            switch search {
            case .idle:
                searchGuide
            case .loading:
                placeholder { ProgressView() }
            case .failed(let text):
                placeholder {
                    VStack(spacing: 12) {
                        message(text)
                        Button("다시 시도", action: onRetry)
                            .moaTextStyle(typography.button2)
                            .foregroundStyle(colors.textNormal)
                            .buttonStyle(.plain)
                    }
                }
            case .loaded(let candidates) where candidates.isEmpty:
                placeholder { message("검색 결과가 없어요") }
            case .loaded(let candidates):
                ScrollView {
                    resultList(candidates)
                        .padding(EdgeInsets(top: 4, leading: 20, bottom: 32, trailing: 20))
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image("Icons/search")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(colors.textAssistive)
                .accessibilityHidden(true)
            TextField(
                "", text: Binding(get: { query }, set: onQueryChange),
                prompt: Text("추가하고 싶은 장소를 검색해주세요").foregroundStyle(colors.textAssistive)
            )
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(MoaMapPrimitiveColors.blue500)
            .submitLabel(.search)
            .focused(focus, equals: .search)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    /// 검색어를 넣기 전에 어떻게 찾으면 되는지 알려 준다.
    private var searchGuide: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("이렇게 검색해보세요")
                .foregroundStyle(colors.textAlternative)
            Group {
                Text("- 도로명 + 건물번호 (위례성대로 2)")
                Text("- 건물명 + 번지 (방이동 44-2)")
                Text("- 건물명, 학교명 (반포 자이, 숭실대학교)")
            }
            .foregroundStyle(colors.textAssistive)
        }
        .moaTextStyle(typography.body3)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding + 4)
        .padding(.top, 86)
    }

    /// 카카오 키워드 검색은 사진을 주지 않아 이름과 주소만 보인다.
    private func resultList(_ candidates: [PlaceCandidate]) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                if index > 0 {
                    Rectangle().fill(colors.lineAlternative).frame(height: 1)
                }
                Button { onSelect(candidate) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.name)
                            .moaTextStyle(typography.subtitle2)
                            .lineLimit(1)
                        if !candidate.displayAddress.isEmpty {
                            Text(candidate.displayAddress)
                                .moaTextStyle(typography.caption0)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(colors.textNormal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.lineAlternative, lineWidth: 1) }
        .shadow(color: .black.opacity(0.04), radius: 2)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textAssistive)
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 240)
    }
}

/// 고른 장소를 지도에 찍어 맞는 곳인지 확인한다.
struct AddPlaceLocationContent: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let candidate: PlaceCandidate
    let onBack: () -> Void
    let onConfirm: () -> Void

    @State private var viewport: Viewport
    @State private var sheetHeight: CGFloat = 0

    init(candidate: PlaceCandidate, onBack: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.candidate = candidate
        self.onBack = onBack
        self.onConfirm = onConfirm
        let point = CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude)
        _viewport = State(initialValue: .camera(center: point, zoom: Self.zoom))
    }

    /// 건물과 길 이름이 읽히는 배율.
    private static let zoom = 16.0

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: candidate.latitude, longitude: candidate.longitude)
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "지도에서 위치 확인", onBack: onBack)
            PlaceMarkerMap(places: [marker], viewport: $viewport, allowsRotation: false)
                // 시트에 가리지 않게 시트 위 남은 칸의 가운데에 장소를 둔다.
                .onChange(of: sheetHeight) { _, height in
                    viewport = .overview(
                        geometry: Point(coordinate),
                        geometryPadding: SwiftUI.EdgeInsets(top: 0, leading: 0, bottom: height, trailing: 0),
                        maxZoom: Self.zoom
                    )
                }
                .overlay(alignment: .bottom) { sheet }
        }
    }

    /// 마커는 장소 분류에 맞는 아이콘으로 그린다. 아직 등록 전이라 id 는 쓰지 않는다.
    private var marker: MapPlace {
        MapPlace(
            id: 0, name: candidate.name, address: candidate.displayAddress,
            latitude: candidate.latitude, longitude: candidate.longitude, photoURL: nil,
            category: candidate.category ?? ""
        )
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(candidate.name)
                    .moaTextStyle(typography.title3)
                if !candidate.displayAddress.isEmpty {
                    Text(candidate.displayAddress)
                        .moaTextStyle(typography.subtitle4)
                }
            }
            .foregroundStyle(colors.textNormal)
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Image("Icons/info")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("표시된 장소가 맞는지 확인해주세요")
                    .moaTextStyle(typography.body2)
            }
            .foregroundStyle(colors.textAssistive)
            PlaceImportButton(text: "이 위치로 장소 추가하기", height: 49, action: onConfirm)
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .padding(.top, 80)
        .padding(.bottom, 12)
        .overlay(alignment: .top) { SheetGrabber().padding(.top, 5) }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                .fill(colors.backgroundSecondary)
                .shadow(color: .black.opacity(0.18), radius: 18.75, y: 15)
                .ignoresSafeArea(edges: .bottom)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
    }
}

/// 등록 폼 맨 위에 고른 장소를 보여 준다. 카카오 검색은 사진을 주지 않아 늘 기본 사진이다.
private struct SelectedPlaceCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let name: String
    let address: String

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: nil, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .moaTextStyle(typography.subtitle2)
                    .lineLimit(1)
                if !address.isEmpty {
                    Text(address)
                        .moaTextStyle(typography.caption0)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(colors.textNormal)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(MoaMapPrimitiveColors.yellow50, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
        .shadow(color: .black.opacity(0.04), radius: 2)
    }
}

/// 장소에 사진·태그·메모를 붙이는 폼. 장소 가져오기의 편집도 같은 폼을 쓴다.
struct AddPlaceFormContent: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let name: String
    let address: String
    let photos: [UploadImage]
    let tags: [String]
    let tagInput: String
    let memo: String
    let focus: FocusState<AddPlaceField?>.Binding
    let onAddPhoto: () -> Void
    let onRemovePhoto: (Int) -> Void
    /// 입력을 반영하고 확정되지 않고 남은 입력을 돌려준다.
    let onTagInputChange: (String) -> String
    let onTagBackspace: () -> Void
    let onRemoveTag: (String) -> Void
    let onMemoChange: (String) -> Void

    /// TextField에 붙는 입력 중인 글자. 확정된 결과는 `tagInput`으로 다시 받는다.
    @State private var tagDraft = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SelectedPlaceCard(name: name, address: address)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("사진")
                                .moaTextStyle(typography.subtitle1)
                                .foregroundStyle(colors.textNormal)
                            optionalLabel
                        }
                        photoSection
                    }
                    // 시안상 태그에는 (선택) 표시가 없다. 태그 없이도 등록은 된다.
                    field("태그", optional: false) {
                        if !tags.isEmpty {
                            ScrollView(.horizontal) {
                                HStack(spacing: 4) {
                                    ForEach(tags, id: \.self) { tagChip($0) }
                                }
                            }
                            .scrollIndicators(.hidden)
                        }
                        // Binding setter 안에서 값을 비우면 TextField가 화면에 반영하지 않는다.
                        // 그래서 입력은 그대로 받아 두고, 확정과 되돌려 받기는 onChange에서 한다.
                        inputField(text: $tagDraft, placeholder: "태그 입력 후 스페이스 또는 엔터", focused: focus.wrappedValue == .tag)
                        .focused(focus, equals: .tag)
                        .onChange(of: tagDraft) { _, draft in
                            // 확정 뒤 남은 값이 이전과 같아도 입력창은 맞춰야 한다. 빈 칸에 "카페 "를 붙여넣는 경우 등.
                            let remaining = onTagInputChange(draft)
                            if remaining != draft { tagDraft = remaining }
                        }
                        .onChange(of: tagInput, initial: true) { _, input in
                            if tagDraft != input { tagDraft = input }
                        }
                        .onChange(of: focus.wrappedValue) { old, new in
                            // 엔터 없이 입력창을 벗어나도 입력 중이던 태그를 확정한다.
                            if old == .tag, new != .tag { _ = onTagInputChange(tagInput + "\n") }
                        }
                        .submitLabel(.next)
                        .onSubmit {
                            // 엔터는 줄바꿈과 같이 태그를 확정한다. 키보드는 내리지 않는다.
                            _ = onTagInputChange(tagInput + "\n")
                            focus.wrappedValue = .tag
                        }
                        .onKeyPress(.delete) {
                            guard tagInput.isEmpty, !tags.isEmpty else { return .ignored }
                            onTagBackspace()
                            return .handled
                        }
                        .id(AddPlaceField.tag)
                    }
                    field("메모", optional: true) {
                        inputField(
                            text: Binding(get: { memo }, set: onMemoChange),
                            placeholder: "메모를 남겨보세요",
                            focused: focus.wrappedValue == .memo
                        )
                        .focused(focus, equals: .memo)
                        .id(AddPlaceField.memo)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            // 키보드가 올라오면 시스템은 글자 한 줄만 보이게 스크롤해서, 입력칸의 흰 배경이 아래 버튼에 잘린다.
            // 입력칸 전체가 보이게 직접 맞춘다. 키보드가 이미 떠 있을 때 칸을 옮기는 경우와, 키보드가 다 올라온 뒤 둘 다 맞춘다.
            .onChange(of: focus.wrappedValue) { _, field in scroll(proxy, to: field) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                scroll(proxy, to: focus.wrappedValue)
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to field: AddPlaceField?) {
        guard let field, field != .search else { return }
        withAnimation { proxy.scrollTo(field, anchor: .bottom) }
    }

    private var optionalLabel: some View {
        Text("(선택)")
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textAlternative)
    }

    /// 입력칸 묶음. 사진 묶음보다 제목이 한 단계 작다.
    private func field(_ title: String, optional: Bool, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textNormal)
                if optional { optionalLabel }
            }
            .padding(.leading, 2)
            content()
        }
    }

    private var photoSection: some View {
        PhotoAttachmentRow(
            photos: photos,
            canAddPhoto: photos.count < AddPlaceUiState.maxPhotos,
            onAddPhoto: onAddPhoto,
            onRemovePhoto: onRemovePhoto
        )
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 2) {
            Text(tag)
                .moaTextStyle(typography.caption0)
                .lineLimit(1)
            Button { onRemoveTag(tag) } label: {
                Image("Icons/close")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tag) 태그 빼기")
        }
        .foregroundStyle(MoaMapPrimitiveColors.yellow900)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
        .overlay { Capsule().strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
    }

    private func inputField(text: Binding<String>, placeholder: String, focused: Bool) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(colors.textAssistive))
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(MoaMapPrimitiveColors.blue500)
            .padding(.horizontal, 16)
            // 비어 있을 때 안내 문구가 입력한 글자보다 키가 커서 높이가 달라진다. 위아래 12 + 줄 높이로 고정한다.
            .frame(height: 12 * 2 + typography.body2.lineHeight)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            // 입력 중인 칸에 선택 테두리를 보여 준다. 프로필 편집과 같다.
            .overlay { if focused { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.primary, lineWidth: 1) } }
            .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

/// 첨부한 사진 줄. 장소 추가와 게시물 작성이 같은 모양을 쓴다.
struct PhotoAttachmentRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let photos: [UploadImage]
    /// 최대 장수가 차면 더 붙일 수 없다.
    let canAddPhoto: Bool
    let onAddPhoto: () -> Void
    let onRemovePhoto: (Int) -> Void

    var body: some View {
        if photos.isEmpty {
            Button(action: onAddPhoto) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MoaMapPrimitiveColors.white)
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .shadow(color: .black.opacity(0.04), radius: 4)
                    .overlay {
                        VStack(spacing: 2) {
                            Image("Icons/add")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 32, height: 32)
                            Text("사진 추가하기")
                                .moaTextStyle(typography.body2)
                        }
                        .foregroundStyle(colors.textAssistive)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        photoTile(photo, index: index)
                    }
                    if canAddPhoto {
                        Button(action: onAddPhoto) {
                            Image("Icons/add")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundStyle(colors.textAssistive)
                                .frame(width: 96, height: 96)
                                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.lineNormal, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("사진 추가하기")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func photoTile(_ photo: UploadImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: photo.data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    MoaMapPrimitiveColors.gray50
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("첨부한 사진")
            Button { onRemovePhoto(index) } label: {
                Image("Icons/close")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(MoaMapPrimitiveColors.white)
                    .frame(width: 24, height: 24)
                    .background(MoaMapPrimitiveColors.transparentBlack, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("사진 빼기")
        }
    }
}

#if DEBUG
#Preview {
    let viewModels = MapDetailViewModels.preview(mapID: 1)
    AddPlaceView(viewModel: viewModels.addPlace, map: .previewJoined, onClose: {})
}

extension MapDetail {
    static let previewJoined = MapDetail(
        id: 1, title: "성수 카페 투어", description: nil, imageURL: nil, ownerName: nil, type: .community, role: .member,
        tags: [], memberCount: 3, placeCount: 5, joined: true, personal: false, inviteCode: nil
    )
}
#endif
