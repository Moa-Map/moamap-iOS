import SwiftUI

/// 장소 가져오기 단계들이 함께 쓰는 틀. 상단바, 안내, 스크롤 내용, 하단 고정 버튼으로 이뤄진다.
struct PlaceImportScaffold<Content: View, Buttons: View>: View {
    @Environment(\.moaColors) private var colors

    let title: String
    let description: String
    /// 실패 안내를 띄울 화면이면 넘긴다. 안내는 버튼 위에 뜬다.
    var errorSource: PlaceImportViewModel?
    let onBack: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        VStack(spacing: 0) {
            PlaceImportTopBar(onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PlaceImportHeader(title: title, description: description)
                    content()
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 23)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .modifier(OptionalSnackbar(viewModel: errorSource))
        }
        .safeAreaInset(edge: .bottom) { PlaceImportBottomBar(content: buttons) }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct PlaceImportTopBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text("장소 가져오기")
                .moaTextStyle(typography.title3)
                .foregroundStyle(MoaMapPrimitiveColors.black)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onBack) {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                Spacer()
            }
            .padding(.leading, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 52)
    }
}

/// 단계 상단의 제목과 설명. 시안상 4 더 들어가 있다.
struct PlaceImportHeader: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).moaTextStyle(typography.subtitle1)
            Text(description).moaTextStyle(typography.body2)
        }
        .foregroundStyle(colors.textNormal)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 화면 아래 고정 버튼 행. 스크롤한 내용이 비치지 않게 배경을 깐다.
struct PlaceImportBottomBar<Content: View>: View {
    @Environment(\.moaColors) private var colors

    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 8, content: content)
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.vertical, 12)
            .background(colors.backgroundSecondary)
    }
}

struct PlaceImportButton: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    enum Style { case primary, secondary }

    let text: String
    var style = Style.primary
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .moaTextStyle(typography.button0)
                .foregroundStyle(colors.textWhite)
                .lineLimit(1)
                .padding(.horizontal, style == .primary ? 10 : 24)
                .padding(.vertical, 14)
                .frame(maxWidth: style == .primary ? .infinity : nil)
                .background(
                    style == .primary && enabled ? colors.primary : MoaMapPrimitiveColors.gray200,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(PlaceImportButtonStyle())
        .disabled(!enabled)
    }
}

/// 비활성일 때 흐려지지 않게 한다. 회색 배경으로 이미 구분된다.
private struct PlaceImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// 장소 이름·주소. 편집 목록은 붙인 것을 한 줄 더 보여준다.
struct PlaceImportLabels: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let place: ImportedPlace
    var extra: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name).moaTextStyle(typography.subtitle2)
            Text(place.displayAddress).moaTextStyle(typography.caption0)
            if let extra {
                Text(extra).moaTextStyle(typography.caption0).foregroundStyle(colors.primary)
            }
        }
        .lineLimit(1)
        .foregroundStyle(colors.textNormal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 추출된 장소 후보. 여러 개 고를 수 있어 파란 테두리와 체크박스로 표시한다.
struct ImportedPlaceCard: View {
    @Environment(\.moaColors) private var colors

    let place: ImportedPlace
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 추출 응답에 사진이 없어 늘 기본 사진이다.
                PhotoThumbnail(imageURL: nil, size: 64)
                PlaceImportLabels(place: place)
                SelectionCheckBox(checked: selected)
            }
            .padding(16)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if selected { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.primary, lineWidth: 1) }
            }
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
        .buttonStyle(.plain)
        // 등록 키가 없는 후보는 눌러도 고를 수 없다.
        .disabled(!place.savable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 편집 단계의 장소 카드. 카드는 눌리지 않고 편집하기만 눌린다.
struct EditablePlaceCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let place: ImportedPlace
    let edit: PlaceEdit?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: nil, size: 64)
            PlaceImportLabels(place: place, extra: edit.flatMap(Self.summary))
            Button(action: onEdit) {
                Text("편집하기")
                    .moaTextStyle(typography.button4)
                    .underline()
                    .foregroundStyle(colors.statusAlert)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(place.name) 편집하기")
        }
        .padding(16)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    /// 붙인 것을 한 줄로 알린다. 태그는 이름이 길 수 있어 개수만 센다.
    private static func summary(_ edit: PlaceEdit) -> String? {
        var parts: [String] = []
        if !edit.photos.isEmpty { parts.append("사진 \(edit.photos.count)") }
        if !edit.tags.isEmpty { parts.append("태그 \(edit.tags.count)") }
        if !edit.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append("메모") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 지도 선택 화면 위의 고른 장소. 접으면 첫 장소와 남은 개수만, 펼치면 모두 보여준다.
struct SelectedPlacesCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let places: [ImportedPlace]
    @State private var expanded = false

    var body: some View {
        if let first = places.first {
            let rest = places.dropFirst()
            VStack(spacing: 12) {
                row(first) {
                    if !rest.isEmpty {
                        HStack(spacing: 0) {
                            Text("외 \(rest.count)개의 장소").moaTextStyle(typography.caption0).lineLimit(1)
                            Image("Icons/arrow-right").renderingMode(.template).resizable()
                                .frame(width: 14, height: 14)
                                .rotationEffect(.degrees(expanded ? -90 : 90))
                        }
                        .foregroundStyle(colors.textAssistive)
                    }
                }
                if expanded {
                    ForEach(rest) { place in
                        Rectangle().fill(MoaMapPrimitiveColors.yellow200).frame(height: 1)
                        row(place) { EmptyView() }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, expanded ? 12 : 16)
            .background(MoaMapPrimitiveColors.yellow50, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
            .shadow(color: .black.opacity(0.08), radius: 4)
            .contentShape(Rectangle())
            .onTapGesture { if !rest.isEmpty { expanded.toggle() } }
            .accessibilityElement(children: .combine)
            .accessibilityHint(rest.isEmpty ? "" : (expanded ? "고른 장소 접기" : "고른 장소 모두 보기"))
        }
    }

    private func row(_ place: ImportedPlace, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: nil, size: 64)
            PlaceImportLabels(place: place)
            trailing()
        }
    }
}

/// 화면이 보일 때만 안내를 받는다. 쌓여 있는 아래 화면이 먼저 받아 가려지지 않게 한다.
private struct OptionalSnackbar: ViewModifier {
    let viewModel: PlaceImportViewModel?
    @State private var visible = false

    func body(content: Content) -> some View {
        if let viewModel {
            content
                .moaSnackbar(Binding(
                    get: { visible ? viewModel.uiState.errorMessage : nil },
                    set: { if $0 == nil { viewModel.consumeError() } }
                ))
                .onAppear { visible = true }
                .onDisappear { visible = false }
        } else {
            content
        }
    }
}
