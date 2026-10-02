/// 지도 상세 한 화면이 함께 쓰는 ViewModel 묶음.
@MainActor
struct MapDetailViewModels {
    let main: MapDetailViewModel
    let personalMap: PersonalMapAddViewModel
}

#if DEBUG
@MainActor
final class PreviewPersonalMapRepository: PersonalMapRepository {
    func addPlace(placeID: Int64) async throws {}
}

extension MapDetailViewModels {
    static func preview(mapID: Int64) -> MapDetailViewModels {
        MapDetailViewModels(
            main: MapDetailViewModel(mapID: mapID, repository: PreviewMapDetailRepository()),
            personalMap: PersonalMapAddViewModel(repository: PreviewPersonalMapRepository())
        )
    }
}
#endif
