import SwiftUI

/// 새 게시물. 로그 탭의 `+` 버튼에서 들어오고 지도 상세 위를 덮는다.
/// 태그할 장소는 지도 상세가 이미 불러온 목록에서 고른다.
struct MapPostCreateView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: MapPostCreateViewModel
    let places: [MapPlace]
    let onClose: () -> Void

    @State private var showsPhotoPicker = false
    @State private var showsPlacePicker = false
    @State private var errorMessage: String?
    @FocusState private var contentFocused: Bool

    private var state: MapPostCreateUiState { viewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "새 게시물", onBack: onClose)
            ScrollView {
                VStack(spacing: 12) {
                    PhotoAttachmentRow(
                        photos: state.photos,
                        // 올리는 중에는 목록을 바꾸지 못하게 한다. 올린 주소와 목록이 어긋난다.
                        canAddPhoto: state.canAddPhoto && !state.submitting,
                        onAddPhoto: {
                            guard !state.submitting else { return }
                            contentFocused = false
                            showsPhotoPicker = true
                        },
                        onRemovePhoto: { index in if !state.submitting { viewModel.removePhoto(at: index) } }
                    )
                    contentField
                    ForEach(state.places) { place in
                        selectedPlaceRow(place)
                    }
                    if state.canAddPlace {
                        addPlaceRow
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            submitButton
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 하고, 빈 곳을 누르면 키보드를 내린다.
        .contentShape(Rectangle())
        .onTapGesture { contentFocused = false }
        .overlay {
            if showsPlacePicker {
                MapPostPlacePicker(
                    // 같은 장소를 두 번 태그하면 서버가 거절한다.
                    places: places.filter { place in !state.places.contains { $0.id == place.id } },
                    onSelect: { place in
                        showsPlacePicker = false
                        viewModel.addPlace(place)
                    },
                    onBack: { showsPlacePicker = false }
                )
            }
        }
        .fullScreenCover(isPresented: $showsPhotoPicker) {
            PhotoLibraryPicker(
                maxSelection: MapPostCreateUiState.maxPhotos - state.photos.count,
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

    private var contentField: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextField(
                "",
                // 메서드를 그대로 넘기면 Swift 6.3 컴파일러가 IR 생성 중에 죽는다(CI).
                text: Binding(get: { state.content }, set: { viewModel.updateContent($0) }),
                prompt: Text("텍스트를 입력해주세요.").foregroundStyle(colors.textAssistive),
                axis: .vertical
            )
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(colors.primary)
            .focused($contentFocused)
            .disabled(state.submitting)
            .frame(minHeight: 56, alignment: .topLeading)
            // 한도에 닿으면 더 써지지 않는다. 왜 안 써지는지 보이게 남은 양을 적는다.
            Text("\(state.content.count)/\(MapPostCreateUiState.maxContentLength)")
                .moaTextStyle(typography.caption0)
                .foregroundStyle(colors.textAssistive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            // 입력하고 있는 칸은 하늘색 테두리를 두른다.
            if contentFocused { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.blue300, lineWidth: 1) }
        }
        .shadow(color: .black.opacity(0.04), radius: 4)
        .contentShape(Rectangle())
        .onTapGesture { contentFocused = true }
    }

    private var addPlaceRow: some View {
        Button {
            guard !state.submitting else { return }
            contentFocused = false
            showsPlacePicker = true
        } label: {
            HStack(spacing: 8) {
                icon("Icons/location")
                Text("장소 추가")
                    .moaTextStyle(typography.subtitle2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                icon("Icons/arrow-right")
            }
            .foregroundStyle(colors.textNormal)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectedPlaceRow(_ place: SelectedPostPlace) -> some View {
        HStack(spacing: 8) {
            icon("Icons/location")
                .foregroundStyle(colors.textNormal)
            MapPostPlaceLabel(name: place.name, address: place.address)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { if !state.submitting { viewModel.removePlace(id: place.id) } } label: {
                icon("Icons/close")
                    .foregroundStyle(colors.textNormal)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("장소 빼기")
        }
        .frame(minHeight: 44)
    }

    private func icon(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .frame(width: 24, height: 24)
    }

    private var submitButton: some View {
        Button(action: viewModel.submit) {
            ZStack {
                if state.submitting {
                    ProgressView().tint(colors.textWhite)
                } else {
                    Text("공유하기")
                        .moaTextStyle(typography.button0)
                        .foregroundStyle(colors.textWhite)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                state.canSubmit || state.submitting ? colors.primary : MoaMapPrimitiveColors.gray200,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!state.canSubmit)
    }
}

private struct MapPostPlaceLabel: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let name: String
    let address: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .moaTextStyle(typography.subtitle4)
                .foregroundStyle(colors.textNormal)
                .lineLimit(1)
            if !address.isEmpty {
                Text(address)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAssistive)
                    .lineLimit(1)
            }
        }
    }
}

/// 이 지도에 등록된 장소에서 고른다. 작성 화면 위를 덮는 한 장이다.
private struct MapPostPlacePicker: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let places: [MapPlace]
    let onSelect: (MapPlace) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "장소 선택", onBack: onBack)
            if places.isEmpty {
                Text("태그할 수 있는 장소가 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(places) { place in
                            Button { onSelect(place) } label: {
                                MapPostPlaceLabel(name: place.name, address: place.address)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 작성 화면으로 터치가 새지 않게 한다.
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview {
    MapPostCreateView(
        viewModel: MapPostCreateViewModel(mapID: 1, repository: PreviewMapPostRepository()),
        places: [],
        onClose: {}
    )
}
#endif
