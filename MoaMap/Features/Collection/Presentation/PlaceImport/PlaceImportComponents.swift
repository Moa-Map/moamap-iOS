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
            MoaMapTopBar(title: "장소 가져오기", onBack: onBack)
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
    /// 정하지 않으면 글자 위아래 여백으로 높이가 정해진다.
    var height: CGFloat?
    var enabled = true
    /// 요청을 기다리는 중. 글자 대신 스피너를 보이고 누를 수 없게 한다. 색은 그대로 둔다.
    var loading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .moaTextStyle(typography.button0)
                .foregroundStyle(colors.textWhite)
                .lineLimit(1)
                // 글자 자리를 그대로 두어 스피너로 바뀌어도 버튼 크기가 변하지 않는다.
                .opacity(loading ? 0 : 1)
                .overlay { if loading { ProgressView().tint(colors.textWhite) } }
                .padding(.horizontal, style == .primary ? 10 : 24)
                .padding(.vertical, height == nil ? 14 : 0)
                .frame(maxWidth: style == .primary ? .infinity : nil)
                .frame(height: height)
                .background(
                    style == .primary && enabled ? colors.primary : MoaMapPrimitiveColors.gray200,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .shadow(color: .black.opacity(0.1), radius: 5)
        }
        .buttonStyle(PlaceImportButtonStyle())
        .disabled(!enabled || loading)
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

/// 외부 지도에서 다 가져오지 못한 까닭. 리스트가 잘렸거나 위치를 못 찾은 곳이 있을 때만 보인다.
/// 항목마다 개수를 굵게 앞세우고 까닭은 아래 작게 둔다. 못 찾은 곳은 눌러 이름을 펼친다.
struct MapShareReportNotice: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let report: MapShareReport

    @State private var showsMissed = false

    var body: some View {
        if report.truncated || !report.missedNames.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                if report.truncated {
                    row(title: truncatedTitle, detail: "한 번에 \(report.extractedCount)곳까지만 불러올 수 있어요")
                }
                if report.truncated && !report.missedNames.isEmpty {
                    Rectangle().fill(colors.lineAlternative).frame(height: 1)
                }
                if !report.missedNames.isEmpty {
                    missedSection
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
    }

    private var truncatedTitle: String {
        if let declared = report.declaredCount, declared > report.extractedCount {
            return "\(declared - report.extractedCount)곳은 가져오지 못했어요"
        }
        return "일부 장소는 가져오지 못했어요"
    }

    private var missedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { showsMissed.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    row(title: "\(report.missedNames.count)곳은 위치를 찾지 못했어요", detail: "이름이 다르거나 검색되지 않는 장소예요")
                    Image("Icons/arrow-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(colors.textAssistive)
                        .rotationEffect(.degrees(showsMissed ? -90 : 90))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(showsMissed ? "목록을 접습니다" : "찾지 못한 장소 이름을 펼칩니다")

            if showsMissed {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(report.missedNames.enumerated()), id: \.offset) { _, name in
                        Text(name)
                            .moaTextStyle(typography.caption0)
                            .foregroundStyle(colors.textAlternative)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colors.backgroundSecondary, in: Capsule())
                    }
                }
                .padding(.leading, 28)
            }
        }
    }

    /// 아이콘 + 굵은 제목 + 작은 설명.
    private func row(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image("Icons/info")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(colors.textAssistive)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .moaTextStyle(typography.body3)
                    .foregroundStyle(colors.textNormal)
                Text(detail)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAlternative)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
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
            // 추출 응답에 사진이 없어 이름과 주소만 보인다.
            HStack(spacing: 8) {
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
        HStack(spacing: 8) {
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
            VStack(spacing: 16) {
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
            .padding(.vertical, expanded ? 20 : 16)
            .background(MoaMapPrimitiveColors.yellow50, in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
            .shadow(color: .black.opacity(0.04), radius: 4)
            .contentShape(Rectangle())
            .onTapGesture { if !rest.isEmpty { expanded.toggle() } }
            .accessibilityElement(children: .combine)
            .accessibilityHint(rest.isEmpty ? "" : (expanded ? "고른 장소 접기" : "고른 장소 모두 보기"))
        }
    }

    private func row(_ place: ImportedPlace, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 8) {
            PlaceImportLabels(place: place)
            trailing()
        }
        .padding(.horizontal, 2)
    }
}

/// 화면이 보일 때만 안내를 받는다. 쌓여 있는 아래 화면이 먼저 받아 가려지지 않게 한다.
struct OptionalSnackbar: ViewModifier {
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
