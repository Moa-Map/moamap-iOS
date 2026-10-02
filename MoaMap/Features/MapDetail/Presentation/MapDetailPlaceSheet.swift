import SwiftUI

/// 지도 위에 늘 떠 있는 장소 목록 시트. 접으면 칩 줄까지만 보인다.
struct MapDetailPlaceSheet: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let places: [MapPlace]
    /// 응답이 오기 전에는 nil 이라 개수를 감춘다.
    let placeCount: Int?
    /// 공식지도는 검색·칩·하트 없이 이름·주소 카드만 둔다.
    let official: Bool
    let categoryFilters: [PlaceCategoryFilter]
    let selectedCategory: PlaceCategoryFilter
    @Binding var searchQuery: String
    @Binding var expanded: Bool
    /// 접힌 높이. 지도 컨트롤이 이 위에 놓인다.
    @Binding var collapsedHeight: CGFloat
    let maxHeight: CGFloat
    let onCategorySelect: (PlaceCategoryFilter) -> Void
    let onPlaceClick: (Int64) -> Void
    let onLikeClick: (Int64) -> Void

    static let expandedHeight: CGFloat = 698
    static let defaultCollapsedHeight: CGFloat = 237
    /// 칩 줄 아래로 남기는 여백. 목록 첫 줄이 살짝 비쳐 더 있다는 걸 알린다.
    private static let headerBottomGap: CGFloat = 12
    /// 공식지도는 제목만 보이면 비어 보여 첫 카드가 다 보이게 둔다.
    private static let officialPeekBelowHeader: CGFloat = 160

    @GestureState private var dragOffset: CGFloat = 0
    @FocusState private var searchFocused: Bool

    private var fullHeight: CGFloat { min(Self.expandedHeight, maxHeight) }

    var body: some View {
        let base = expanded ? fullHeight : collapsedHeight
        let height = min(max(base - dragOffset, collapsedHeight), fullHeight)

        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight in
                    collapsedHeight = headerHeight + (official ? Self.officialPeekBelowHeader : Self.headerBottomGap)
                }
            content
        }
        .frame(height: height, alignment: .top)
        .frame(maxWidth: .infinity)
        .clipped()
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38)
                .fill(colors.backgroundSecondary)
                .shadow(color: .black.opacity(0.12), radius: 10)
                .ignoresSafeArea(edges: .bottom)
        }
        .animation(.easeOut(duration: 0.25), value: expanded)
        .onChange(of: searchFocused) { _, focused in
            // 접힌 시트에서는 목록이 안 보인다. 검색창을 누른 김에 끝까지 올린다.
            if focused { expanded = true }
        }
        .onChange(of: expanded) { _, isExpanded in
            if !isExpanded { searchFocused = false }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(MoaMapPrimitiveColors.gray100)
                    .frame(width: 35, height: 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 25)
                Text(placeCount.map { "장소 \($0)곳" } ?? "장소")
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onTapGesture { expanded.toggle() }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "장소 목록을 접습니다" : "장소 목록을 펼칩니다")

            if !official {
                searchField
                    .padding(.top, 16)
                chips
                    .padding(.top, 12)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragOffset) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                if predicted < -80 { expanded = true } else if predicted > 80 { expanded = false }
            }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image("Icons/search")
                .renderingMode(.template)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(colors.textAssistive)
                .accessibilityHidden(true)
            TextField("", text: $searchQuery, prompt: Text("장소를 검색해보세요").foregroundStyle(colors.textAssistive))
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .submitLabel(.search)
                .focused($searchFocused)
                .onSubmit { searchFocused = false }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(colors.textWhite, in: Capsule())
        .shadow(color: .black.opacity(0.04), radius: 4)
        .padding(.horizontal, 20)
    }

    /// 장소가 없어도 전체 칩만 두고 줄은 남긴다. 줄이 사라지면 접힌 높이가 지도마다 달라진다.
    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(categoryFilters, id: \.self) { filter in
                    CategoryChip(title: filter.label, isSelected: filter == selectedCategory) {
                        onCategorySelect(filter)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, -6)
    }

    @ViewBuilder
    private var content: some View {
        if places.isEmpty {
            Text(emptyMessage)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(places) { place in
                        PlaceListItem(
                            place: place,
                            showsReactions: !official,
                            onClick: { onPlaceClick(place.id) },
                            onLikeClick: { onLikeClick(place.id) }
                        )
                    }
                }
                // 칩 줄과의 간격을 목록 안에 둬야 첫 카드 그림자가 잘리지 않는다.
                .padding(EdgeInsets(top: official ? 20 : 16, leading: 20, bottom: 20, trailing: 20))
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var emptyMessage: String {
        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty { return "검색 결과가 없어요" }
        if selectedCategory != .all { return "이 카테고리의 장소가 없어요" }
        return "아직 등록된 장소가 없어요"
    }
}

/// 묶음 마커를 펼친 목록. 좌표가 같은 장소는 확대해도 갈라지지 않아 여기서 골라 연다.
struct ClusterPlacesSheet: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let places: [MapPlace]
    let showsReactions: Bool
    let onPlaceClick: (Int64) -> Void
    let onLikeClick: (Int64) -> Void

    /// 낮은 줌에서는 묶음이 얼마든 커질 수 있어 시트가 화면을 다 먹지 않게 잡는다.
    private static let listMaxHeight: CGFloat = 456

    @State private var listHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(MoaMapPrimitiveColors.gray100)
                    .frame(width: 35, height: 5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 25)
                Text("이 위치의 장소 \(places.count)곳")
                    .moaTextStyle(typography.title3)
                    .foregroundStyle(colors.textNormal)
                    .padding(.horizontal, 20)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(places) { place in
                        PlaceListItem(
                            place: place,
                            showsReactions: showsReactions,
                            onClick: { onPlaceClick(place.id) },
                            onLikeClick: { onLikeClick(place.id) }
                        )
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 20, bottom: 20, trailing: 20))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
            }
            .frame(height: min(listHeight, Self.listMaxHeight))
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(headerHeight + min(listHeight, Self.listMaxHeight))])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
        .presentationBackground(colors.backgroundSecondary)
    }
}

#Preview {
    @Previewable @State var expanded = false
    @Previewable @State var query = ""
    @Previewable @State var collapsed = MapDetailPlaceSheet.defaultCollapsedHeight
    let places = (1...4).map {
        MapPlace(id: Int64($0), name: "커피나무 \($0)호점", address: "서울 성동구", latitude: 0, longitude: 0, photoURL: nil,
                 description: "스페셜티 커피", category: "음식점 > 카페", reviewCount: 3)
    }
    ZStack(alignment: .bottom) {
        MoaMapPrimitiveColors.blue50.ignoresSafeArea()
        MapDetailPlaceSheet(
            places: places, placeCount: 4, official: false,
            categoryFilters: PlaceCategoryFilter.available(in: places), selectedCategory: .all,
            searchQuery: $query, expanded: $expanded, collapsedHeight: $collapsed, maxHeight: 700,
            onCategorySelect: { _ in }, onPlaceClick: { _ in }, onLikeClick: { _ in }
        )
    }
}
