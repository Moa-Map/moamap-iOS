import Foundation
import Testing
@testable import MoaMap

struct BlockedAuthorFilterTests {
    private func place(_ id: Int64, author: Int64?) -> MapPlace {
        MapPlace(id: id, name: "장소", address: "", latitude: 0, longitude: 0, photoURLs: [], authorID: author)
    }

    private func post(_ id: Int64, author: Int64) -> MapPost {
        MapPost(id: id, authorID: author, content: "", imageURLs: [], placeNames: [], createdAt: nil)
    }

    @Test func 차단한_사람이_등록한_장소만_뺀다() {
        let places = [place(1, author: 3), place(2, author: 4), place(3, author: nil)]
        #expect(places.hiding(authors: [3]).map(\.id) == [2, 3])
        #expect(places.hiding(authors: []).map(\.id) == [1, 2, 3])
    }

    @Test func 차단한_사람이_쓴_게시물만_뺀다() {
        let posts = [post(1, author: 3), post(2, author: 4)]
        #expect(posts.hiding(authors: [3]).map(\.id) == [2])
    }
}
