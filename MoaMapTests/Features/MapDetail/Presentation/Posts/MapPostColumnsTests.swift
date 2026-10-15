import Foundation
import Testing
@testable import MoaMap

struct MapPostColumnsTests {
    private func post(_ id: Int64, photo: Bool = false, content: String = "짧은 글") -> MapPost {
        MapPost(
            id: id, authorID: 1, content: content,
            imageURLs: photo ? [URL(string: "https://p/\(id).jpg")!] : [], placeNames: [], createdAt: nil
        )
    }

    @Test func 낮은_줄에_다음_카드를_붙인다() {
        let columns = MapPostColumns.split([post(1, photo: true), post(2), post(3), post(4)])
        #expect(columns.map { $0.map(\.post.id) } == [[1], [2, 3, 4]])
        #expect(columns[1].map(\.index) == [1, 2, 3])
    }

    @Test func 다음_페이지가_붙어도_앞_카드는_옮겨_가지_않는다() {
        let first = [post(1, photo: true), post(2), post(3)]
        let before = MapPostColumns.split(first)
        let after = MapPostColumns.split(first + [post(4, photo: true), post(5)])
        for (old, new) in zip(before, after) {
            #expect(Array(new.prefix(old.count)) == old)
        }
    }

    @Test func 긴_글은_여섯_줄까지만_센다() {
        let long = post(1, content: String(repeating: "가", count: 500))
        let short = post(2, content: String(repeating: "가", count: 60))
        #expect(MapPostColumns.estimatedHeight(of: long) == MapPostColumns.estimatedHeight(of: short))
    }
}
