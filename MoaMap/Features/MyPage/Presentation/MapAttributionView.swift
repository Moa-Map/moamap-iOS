import SwiftUI

/// 지도 위에서 숨긴 Mapbox 출처 표기와 텔레메트리 설정.
struct MapAttributionView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Mapbox SDK 가 텔레메트리 동의를 읽는 키. 기본값은 켜짐이다.
    @AppStorage("MGLMapboxMetricsEnabled") private var metricsEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "지도 데이터 출처") { dismiss() }
            ScrollView {
                VStack(spacing: 20) {
                    section("출처") {
                        linkRow("© Mapbox", url: "https://www.mapbox.com/about/maps/")
                        linkRow("© OpenStreetMap", url: "https://www.openstreetmap.org/copyright", showsDivider: true)
                        linkRow("지도 개선하기", url: "https://apps.mapbox.com/feedback/", showsDivider: true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        section("Mapbox 텔레메트리") {
                            row("익명 사용 정보 보내기") {
                                Toggle("", isOn: $metricsEnabled)
                                    .labelsHidden()
                                    .tint(colors.primary)
                            }
                        }
                        Text("지도를 개선하는 데 쓰이도록 Mapbox 에 익명 사용 정보를 보내요.")
                            .moaTextStyle(typography.caption2)
                            .foregroundStyle(colors.textAssistive)
                            .padding(.horizontal, 2)
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0, content: content)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.04), radius: 4)
        }
    }

    private func row(_ label: String, showsDivider: Bool = false, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .moaTextStyle(typography.body1)
                .foregroundStyle(colors.textNormal)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle().fill(colors.lineAlternative).frame(height: 1)
            }
        }
    }

    private func linkRow(_ label: String, url: String, showsDivider: Bool = false) -> some View {
        Button { if let url = URL(string: url) { openURL(url) } } label: {
            row(label, showsDivider: showsDivider) {
                Image("Icons/arrow-right").renderingMode(.template).resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(colors.textNormal)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { MapAttributionView() }
}
