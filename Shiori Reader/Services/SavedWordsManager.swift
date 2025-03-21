//
//  SavedWordsManager.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/21/25.
//

import Foundation

// ViewModel to handle saved words data
class SavedWordsManager: ObservableObject {
    @Published var savedWords: [SavedWord] = []
    
    init() {
        loadDummyData()
    }
    
    private func loadDummyData() {
        savedWords = [
            SavedWord(
                word: "受かる",
                reading: "うかる",
                definition: "to pass (examination)",
                sentence: "たくさん勉強したから、試験に受かることができた。",
                timeAdded: Date().addingTimeInterval(-86400 * 7),
                sourceBook: "COTE"
            ),
            SavedWord(
                word: "受ける",
                reading: "うける",
                definition: "to receive (examination)",
                sentence: "明日は大事な試験を受けるので、早く寝ます。",
                timeAdded: Date().addingTimeInterval(-86400 * 6),
                sourceBook: "Mushoku Tensei"
            ),
            SavedWord(
                word: "勉強",
                reading: "べんきょう",
                definition: "study",
                sentence: "日本語の勉強は楽しいけど、難しいです。",
                timeAdded: Date().addingTimeInterval(-86400 * 5),
                sourceBook: "ReZero"
            ),
            SavedWord(
                word: "努力",
                reading: "どりょく",
                definition: "effort",
                sentence: "彼の努力は本当に素晴らしいと思います。",
                timeAdded: Date().addingTimeInterval(-86400 * 4),
                sourceBook: "Hakomari"
            ),
            SavedWord(
                word: "成績",
                reading: "せいせき",
                definition: "grades, performance",
                sentence: "成績が良くなったのは、毎日勉強したからだ。",
                timeAdded: Date().addingTimeInterval(-86400 * 3),
                sourceBook: "Konosuba"
            ),
            SavedWord(
                word: "宿題",
                reading: "しゅくだい",
                definition: "homework",
                sentence: "週末には宿題をたくさんもらいました。",
                timeAdded: Date().addingTimeInterval(-86400 * 2),
                sourceBook: "Oregairu"
            ),
            SavedWord(
                word: "学校",
                reading: "がっこう",
                definition: "school",
                sentence: "毎日学校に行くのが楽しみです。",
                timeAdded: Date().addingTimeInterval(-86400),
                sourceBook: "Danmachi"
            ),
            SavedWord(
                word: "大学",
                reading: "だいがく",
                definition: "university",
                sentence: "大学でコンピュータサイエンスを専攻しています。",
                timeAdded: Date(),
                sourceBook: "86"
            )
        ]
    }
    
    func addWord(_ word: SavedWord) {
        savedWords.append(word)
    }
    
    func updateWord(updated: SavedWord) {
        if let index = savedWords.firstIndex(where: { $0.id == updated.id }) {
            savedWords[index] = updated
        }
    }
    
    func deleteWord(at indexSet: IndexSet) {
        savedWords.remove(atOffsets: indexSet)
    }
    
    func deleteWord(with id: UUID) {
        if let index = savedWords.firstIndex(where: { $0.id == id }) {
            savedWords.remove(at: index)
        }
    }
}
