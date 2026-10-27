import SwiftUI

/// 로그 탭 달력 형식. 위는 한 달 달력, 아래는 고른 날의 게시물이다.
/// 게시물이 많은 날은 달력까지 함께 밀려 올라가도록 한 스크롤 안에 둔다.
struct MapPostCalendarView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.blockedUserIDs) private var blockedUserIDs

    let viewModel: MapPostCalendarViewModel
    let onViewModeSelect: (MapPostViewMode) -> Void
    /// 고른 날의 카드를 누르면 게시물 상세를 연다.
    var onPostClick: (MapPost) -> Void = { _ in }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 펼친 보기 방식 메뉴가 달력 위에 그려지게 한다.
                MapPostsToolbar(viewMode: .calendar, onViewModeSelect: onViewModeSelect)
                    .zIndex(1)
                LazyVStack(spacing: 12) {
                    if let month = viewModel.uiState.month {
                        MonthHeader(
                            month: month,
                            onPrevious: viewModel.showPreviousMonth,
                            onNext: viewModel.showNextMonth
                        )
                        MonthGrid(
                            month: month,
                            covers: viewModel.coverPhotos(hiding: blockedUserIDs),
                            selectedDay: viewModel.uiState.selectedDay,
                            onDaySelect: viewModel.selectDay
                        )
                        .padding(.bottom, 20)
                        dayContent
                    }
                }
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.top, MapPostsView.tabBarClearance)
            .padding(.bottom, MapPostsView.bottomClearance)
        }
        .scrollIndicators(.hidden)
        .background(colors.backgroundSecondary)
        .onAppear { viewModel.open() }
    }

    @ViewBuilder
    private var dayContent: some View {
        switch viewModel.uiState.load {
        case .loading:
            CommunityMapsPlaceholder { ProgressView() }
        case .failed(let message):
            CommunityMapsPlaceholder {
                CommunityMapsError(message: message) { viewModel.retry() }
            }
        case .idle:
            if let day = viewModel.uiState.selectedDay {
                Text("\(day.day)일")
                    .moaTextStyle(typography.subtitle1)
                    .foregroundStyle(colors.textNormal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            let posts = viewModel.selectedDayPosts(hiding: blockedUserIDs)
            if posts.isEmpty {
                Text("이 날은 게시물이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 4)
            } else {
                ForEach(posts) { post in
                    Button { onPostClick(post) } label: {
                        ExpandedPostCard(post: post, dateLabel: viewModel.dateLabel(of: post.createdAt))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MonthHeader: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let month: CalendarMonth
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            arrow("Icons/arrow-left", label: "이전 달", action: onPrevious)
            Text(month.label)
                .moaTextStyle(typography.button0)
                .foregroundStyle(colors.textNormal)
            arrow("Icons/arrow-right", label: "다음 달", action: onNext)
        }
        .frame(maxWidth: .infinity)
    }

    private func arrow(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(colors.textNormal)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 월요일부터 시작한다. 1일 앞과 마지막 주 뒤는 빈칸으로 채워 줄 폭을 맞춘다.
private struct MonthGrid: View {
    @Environment(\.moaTypography) private var typography

    let month: CalendarMonth
    let covers: [Int: URL]
    let selectedDay: CalendarDay?
    let onDaySelect: (CalendarDay) -> Void

    private static let weekdays = ["월", "화", "수", "목", "금", "토", "일"]
    private static let gap: CGFloat = 8

    var body: some View {
        VStack(spacing: Self.gap) {
            HStack(spacing: Self.gap) {
                ForEach(Self.weekdays, id: \.self) { label in
                    Text(label)
                        .moaTextStyle(typography.body3)
                        .foregroundStyle(MoaMapPrimitiveColors.black)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: Self.gap) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, dayOfMonth in
                        if let dayOfMonth {
                            let day = month.day(dayOfMonth)
                            DayCell(
                                day: day,
                                coverURL: covers[dayOfMonth],
                                selected: day == selectedDay,
                                onTap: { onDaySelect(day) }
                            )
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var weeks: [[Int?]] {
        let filled: [Int?] = Array(repeating: nil, count: month.leadingBlankDays) + (1...month.daysInMonth).map { $0 }
        let cells = filled + Array(repeating: nil, count: (7 - filled.count % 7) % 7)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

/// 그날 가장 최신 사진 게시물의 사진으로 채우고, 없으면 회색이다. 숫자는 날짜다.
private struct DayCell: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let day: CalendarDay
    let coverURL: URL?
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            // 칸은 열 폭의 정사각형이고, 사진과 숫자는 그 위에 얹기만 한다.
            PostPhotoFill(url: coverURL)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    Text("\(day.day)")
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textWhite)
                }
                .background(colors.lineAlternative)
                .clipShape(Circle())
                .overlay {
                    if selected { Circle().strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) }
                }
                .background {
                    // 칸 바깥으로 번지는 파란 빛.
                    if selected {
                        Circle()
                            .fill(colors.lineAlternative)
                            .shadow(color: MoaMapPrimitiveColors.blue500.opacity(0.7), radius: 5)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.month)월 \(day.day)일")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 고른 날의 게시물을 크게 보여준다. 사진은 첫 장만 쓴다.
struct ExpandedPostCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let post: MapPost
    let dateLabel: String?

    private static let photoHeight: CGFloat = 313

    var body: some View {
        let placeName = post.placeNames.first
        VStack(alignment: .trailing, spacing: 8) {
            if let photoURL = post.imageURLs.first {
                PostPhotoFill(url: photoURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.photoHeight)
                    .background(colors.lineAlternative)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.textWhite, lineWidth: 1) }
                    .overlay(alignment: .topTrailing) {
                        if let placeName { MapPostPlacePill(name: placeName, style: typography.body2).padding(8) }
                    }
            } else if let placeName {
                MapPostPlacePill(name: placeName, style: typography.body2)
            }
            Group {
                if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(post.content)
                        .moaTextStyle(typography.subtitle2)
                        .foregroundStyle(colors.textNormal)
                }
                if let dateLabel {
                    Text(dateLabel)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAlternative)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    MapPostCalendarView(
        viewModel: MapPostCalendarViewModel(
            mapID: 1, repository: PreviewMapPostRepository(), timeZone: .current, now: Date.init
        ),
        onViewModeSelect: { _ in }
    )
}
#endif
