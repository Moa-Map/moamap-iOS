import SwiftUI

struct PlaceImportURLView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: PlaceImportViewModel
    let onBack: () -> Void
    let onSearch: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        PlaceImportScaffold(
            title: "가져올 장소 url을 입력해주세요",
            description: "링크 속 장소를 자동으로 인식해서 추가해드려요",
            errorSource: viewModel,
            onBack: onBack
        ) {
            // 붙여넣은 내용이 길어도 세 줄까지만 늘어난다.
            TextField(
                // 메서드를 그대로 넘기면 Xcode 26 컴파일러가 크래시해 클로저로 감싼다.
                "", text: Binding(get: { viewModel.uiState.url }, set: { viewModel.updateURL($0) }),
                prompt: Text("url을 입력해주세요").foregroundStyle(colors.textAssistive),
                axis: .vertical
            )
            .lineLimit(1...3)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(colors.primary)
            .accessibilityLabel("가져올 장소 url")
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
        } buttons: {
            PlaceImportButton(text: "검색하기", enabled: viewModel.uiState.canSearch) {
                focused = false
                onSearch()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = false }
    }
}

struct PlaceImportLoadingView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let source: PlaceImportSource
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PlaceImportTopBar(onBack: onCancel)
            VStack(spacing: 24) {
                CircularProgressRing(color: colors.primary)
                    .frame(width: 80, height: 80)
                VStack(spacing: 12) {
                    Text(source == .instagram ? "장소 불러오는 중.." : "지도 불러오는 중..")
                        .moaTextStyle(typography.title1)
                    Text(source == .instagram
                         ? "AI가 영상을 분석하고 있어요.\n최대 30초 정도 걸려요."
                         : "외부 지도에서 장소를 불러오고 있어요.\n잠시만 기다려주세요.")
                        .moaTextStyle(typography.subtitle4)
                }
                .foregroundStyle(MoaMapPrimitiveColors.black)
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
    }
}

/// 원본과 같은 원형 진행 표시. 호가 돌면서 길이가 늘었다 줄어든다.
private struct CircularProgressRing: View {
    let color: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            // 호 길이는 한 바퀴의 10%~75% 사이를 오간다.
            let sweep = 0.1 + 0.65 * (1 - cos(time * .pi / 0.75)) / 2
            Circle()
                .trim(from: 0, to: sweep)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 1.4) / 1.4 * 360 - 90))
                .padding(lineWidth / 2)
        }
        .accessibilityLabel("불러오는 중")
    }
}

struct PlaceImportPlaceView: View {
    let viewModel: PlaceImportViewModel
    let onBack: () -> Void
    let onRetry: () -> Void
    let onNext: () -> Void

    var body: some View {
        let state = viewModel.uiState
        PlaceImportScaffold(
            title: state.source == .instagram ? "이 장소가 맞나요?" : "지도의 장소들을 불러왔어요",
            description: state.source == .instagram
                ? "영상에서 \(state.places.count)곳을 찾았어요!\n맞는 곳을 골라주세요."
                : "추가하고 싶지 않은 장소들은 선택 해제를 해주세요",
            errorSource: viewModel,
            onBack: onBack
        ) {
            LazyVStack(spacing: 8) {
                ForEach(state.places) { place in
                    ImportedPlaceCard(place: place, selected: state.selectedPlaceIDs.contains(place.id)) {
                        viewModel.togglePlace(place.id)
                    }
                }
            }
        } buttons: {
            // 외부 지도는 리스트를 통째로 읽어 다시 뽑아도 같다. 후보를 추리는 인스타그램만 재시도가 의미 있다.
            if state.source == .instagram {
                PlaceImportButton(text: "재시도", style: .secondary, action: onRetry)
            }
            PlaceImportButton(text: "다음으로", enabled: state.canProceed, action: onNext)
        }
    }
}

struct PlaceImportEditView: View {
    let viewModel: PlaceImportViewModel
    let onBack: () -> Void
    let onEdit: (String) -> Void
    let onNext: () -> Void

    var body: some View {
        let state = viewModel.uiState
        PlaceImportScaffold(
            title: "장소를 편집하시겠어요?",
            description: "정보를 수정할 장소를 편집해보세요",
            onBack: onBack
        ) {
            LazyVStack(spacing: 8) {
                ForEach(state.selectedPlaces) { place in
                    EditablePlaceCard(place: place, edit: state.edits[place.id]) { onEdit(place.id) }
                }
            }
        } buttons: {
            // 편집은 선택이라 그대로 넘어갈 수 있다.
            PlaceImportButton(text: "다음으로", action: onNext)
        }
    }
}

/// 고른 장소 하나에 사진·태그·메모를 붙인다. 값은 바꾸는 즉시 반영되고 완료나 뒤로가기로 나간다.
struct PlaceImportEditDetailView: View {
    @Environment(\.moaColors) private var colors

    let viewModel: PlaceImportViewModel
    let place: ImportedPlace
    let onDone: () -> Void

    /// 태그가 되기 전의 입력 중인 글자. 저장할 값이 아니라 화면이 들고 있는다.
    @State private var tagInput = ""
    @State private var showsSourceMenu = false
    @FocusState private var focusedField: AddPlaceField?

    var body: some View {
        let edit = viewModel.uiState.edit(of: place)
        VStack(spacing: 0) {
            PlaceImportTopBar(onBack: onDone)
            AddPlaceFormContent(
                name: place.name,
                address: place.displayAddress,
                photos: edit.photos,
                tags: edit.tags,
                tagInput: tagInput,
                memo: edit.memo,
                focus: $focusedField,
                onAddPhoto: {
                    focusedField = nil
                    showsSourceMenu = true
                },
                onRemovePhoto: { viewModel.removeEditPhoto(place.id, at: $0) },
                onTagInputChange: { input in
                    let result = TagInput.apply(tags: edit.tags, rawInput: input)
                    tagInput = String(result.input.prefix(TagInput.maxLength))
                    if result.tags != edit.tags { viewModel.updateEditTags(place.id, tags: result.tags) }
                },
                onTagBackspace: { viewModel.updateEditTags(place.id, tags: Array(edit.tags.dropLast())) },
                onRemoveTag: { tag in viewModel.updateEditTags(place.id, tags: edit.tags.filter { $0 != tag }) },
                onMemoChange: { viewModel.updateEditMemo(place.id, memo: $0) }
            )
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            PlaceImportBottomBar { PlaceImportButton(text: "완료", action: onDone) }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .imageSourcePicker(isPresented: $showsSourceMenu) { data, type in
            viewModel.addEditPhoto(place.id, data: data, type: type)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct PlaceImportMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: PlaceImportViewModel
    let onBack: () -> Void

    var body: some View {
        let state = viewModel.uiState
        PlaceImportScaffold(
            title: "어디에 저장할까요?",
            description: "이 장소를 추가할 지도를 선택해주세요!",
            errorSource: viewModel,
            onBack: onBack
        ) {
            VStack(spacing: 24) {
                SelectedPlacesCard(places: state.selectedPlaces)
                maps(state)
            }
        } buttons: {
            PlaceImportButton(text: state.saving ? "저장하는 중.." : "저장하기", enabled: state.canSave) {
                viewModel.savePlaces()
            }
        }
    }

    @ViewBuilder private func maps(_ state: PlaceImportUiState) -> some View {
        switch state.targetMaps {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).frame(height: 200)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).moaTextStyle(typography.body2).foregroundStyle(colors.textAssistive)
                Button("다시 시도") { viewModel.loadTargetMaps() }
                    .moaTextStyle(typography.button2)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .foregroundStyle(colors.textWhite)
                    .background(colors.primary, in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity).frame(height: 200)
        case .loaded(let maps) where maps.isEmpty:
            Text("저장할 지도가 없어요")
                .moaTextStyle(typography.body2).foregroundStyle(colors.textAssistive)
                .frame(maxWidth: .infinity).frame(height: 200)
        case .loaded(let maps):
            LazyVStack(spacing: 8) {
                // 한 장소를 여러 지도에 넣을 수 있어 체크박스로 여러 개 고른다.
                ForEach(maps) { map in
                    Button { viewModel.toggleMap(map.id) } label: {
                        CollectionMapCard(map: map, showsMembers: false, selected: state.selectedMapIDs.contains(map.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
