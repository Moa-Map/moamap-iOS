import SwiftUI

/// 장소 추가. 지도 상세 위를 덮는 한 장이고, 검색과 등록 폼 두 단계가 이 안에서 오간다.
struct AddPlaceView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: AddPlaceViewModel
    let map: MapDetail
    /// 어느 단계든 닫는다.
    let onClose: () -> Void

    @State private var showsSourceMenu = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AddPlaceField?

    private var state: AddPlaceUiState { viewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            // 등록 폼이면 검색으로, 검색이면 닫는다.
            BackCloseControls(onBack: { state.isFormStep ? viewModel.backToSearch() : onClose() }, onClose: onClose)
                .padding(.bottom, 8)
            if let selected = state.selected {
                AddPlaceFormContent(
                    candidate: selected,
                    state: state,
                    focus: $focusedField,
                    onAddPhoto: { showsSourceMenu = true },
                    onRemovePhoto: viewModel.removePhoto(at:),
                    onTagInputChange: viewModel.updateTagInput,
                    onTagBackspace: viewModel.removeLastTagIfInputEmpty,
                    onRemoveTag: viewModel.removeTag,
                    onMemoChange: viewModel.updateMemo
                )
                submitButton
            } else {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 하고, 빈 곳을 누르면 키보드를 내린다.
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .imageSourcePicker(isPresented: $showsSourceMenu) { data, type in viewModel.addPhoto(data: data, type: type) }
        .moaSnackbar($errorMessage)
        .onChange(of: state.errorMessage, initial: true) { _, message in
            guard let message else { return }
            errorMessage = message
            viewModel.consumeErrorMessage()
        }
    }

    /// 입력값은 모두 선택이라 처음부터 누를 수 있다. 비활성은 보내는 중일 때뿐이다.
    private var submitButton: some View {
        Button { viewModel.submit(map: map) } label: {
            Text(map.addPlaceButtonLabel)
                .moaTextStyle(typography.button0)
                .foregroundStyle(colors.textWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(state.submitting ? MoaMapPrimitiveColors.gray200 : MoaMapPrimitiveColors.blue500,
                            in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 1.25)
        }
        .buttonStyle(.plain)
        .disabled(state.submitting)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
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
            Text("장소 추가")
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .padding(.horizontal, 20)
            searchField
                .padding(.horizontal, 20)
                .padding(.top, 20)
            switch search {
            case .idle:
                placeholder { message("장소를 검색해보세요") }
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
                    LazyVStack(spacing: 8) {
                        ForEach(candidates) { candidate in
                            Button { onSelect(candidate) } label: { CandidateCard(candidate: candidate) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20))
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
        .background(MoaMapPrimitiveColors.white, in: Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4)
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

/// 검색 결과 카드. 카카오 키워드 검색은 사진을 주지 않아 늘 기본 사진이다.
private struct CandidateCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let candidate: PlaceCandidate
    var highlighted = false

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: nil, size: 64)
            VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, highlighted ? 12 : 16)
        .background(highlighted ? MoaMapPrimitiveColors.yellow50 : MoaMapPrimitiveColors.white,
                    in: RoundedRectangle(cornerRadius: highlighted ? 16 : 12))
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 16).strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.04), radius: 4)
        .contentShape(Rectangle())
    }
}

struct AddPlaceFormContent: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let candidate: PlaceCandidate
    let state: AddPlaceUiState
    let focus: FocusState<AddPlaceField?>.Binding
    let onAddPhoto: () -> Void
    let onRemovePhoto: (Int) -> Void
    let onTagInputChange: (String) -> Void
    let onTagBackspace: () -> Void
    let onRemoveTag: (String) -> Void
    let onMemoChange: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("장소등록")
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                CandidateCard(candidate: candidate, highlighted: true)
                section("사진") { photos }
                section("태그") {
                    if !state.tags.isEmpty {
                        ScrollView(.horizontal) {
                            HStack(spacing: 4) {
                                ForEach(state.tags, id: \.self) { tagChip($0) }
                            }
                        }
                        .scrollIndicators(.hidden)
                        .padding(.bottom, 4)
                    }
                    inputField(
                        text: Binding(get: { state.tagInput }, set: onTagInputChange),
                        placeholder: "태그 입력 후 스페이스 또는 엔터"
                    )
                    .focused(focus, equals: .tag)
                    .submitLabel(.next)
                    .onSubmit {
                        // 엔터는 줄바꿈과 같이 태그를 확정한다. 키보드는 내리지 않는다.
                        onTagInputChange(state.tagInput + "\n")
                        focus.wrappedValue = .tag
                    }
                    .onKeyPress(.delete) {
                        guard state.tagInput.isEmpty, !state.tags.isEmpty else { return .ignored }
                        onTagBackspace()
                        return .handled
                    }
                }
                section("메모") {
                    inputField(text: Binding(get: { state.memo }, set: onMemoChange), placeholder: "메모를 남겨보세요")
                        .focused(focus, equals: .memo)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title).moaTextStyle(typography.subtitle1)
                Text("(선택)").moaTextStyle(typography.body2)
            }
            .foregroundStyle(MoaMapPrimitiveColors.black)
            content()
        }
    }

    @ViewBuilder
    private var photos: some View {
        if state.photos.isEmpty {
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
                    ForEach(Array(state.photos.enumerated()), id: \.offset) { index, photo in
                        photoTile(photo, index: index)
                    }
                    // 다섯 장이 차면 더 붙일 수 없다. 서버 제한이다.
                    if state.canAddPhoto {
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

    private func inputField(text: Binding<String>, placeholder: String) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(colors.textAssistive))
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textNormal)
            .tint(MoaMapPrimitiveColors.blue500)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
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
