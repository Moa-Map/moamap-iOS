#if DEBUG
import SwiftUI

/// UI 테스트가 로그인 없이 화면 하나만 띄운다. 실행 인자 `-UITestScreen <이름>` 으로 고른다.
enum UITestScreen: String {
    case createMap, editMap, inquiry, profileEdit

    init?(arguments: [String]) {
        guard let index = arguments.firstIndex(of: "-UITestScreen"), arguments.indices.contains(index + 1) else { return nil }
        self.init(rawValue: arguments[index + 1])
    }

    @ViewBuilder
    var view: some View {
        NavigationStack {
            switch self {
            case .createMap:
                CreateMapView(
                    viewModel: CreateMapViewModel(repository: PreviewCollectionRepository(), importRepository: PreviewPlaceImportRepository()),
                    onImportPlaces: { _ in }, onCreated: { _, _ in }
                )
            case .editMap:
                EditMapView(
                    viewModel: EditMapViewModel(
                        map: MapDetail(
                            id: 1, title: "숭실대 주변 맛집", description: "학교 주변 맛집", imageURL: nil,
                            ownerName: "모아", type: .community, role: .owner, tags: ["맛집"], memberCount: 3, placeCount: 10,
                            joined: true, personal: false, inviteCode: nil
                        ),
                        repository: PreviewCollectionRepository()
                    ),
                    onBack: {}, onSaved: {}
                )
            case .inquiry:
                InquiryView(viewModel: InquiryViewModel(repository: PreviewInquiryRepository(), userRepository: PreviewUserRepository()))
            case .profileEdit:
                ProfileEditView(viewModel: ProfileEditViewModel(repository: PreviewUserRepository()), onSaved: { _ in })
            }
        }
    }
}
#endif
