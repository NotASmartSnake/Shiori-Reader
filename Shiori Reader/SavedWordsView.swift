//
//  SavedWordsView.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/13/25.
//


import SwiftUI

struct SavedWordsView: View {
    
    let words: [String: String] = [
        "受かる": "to pass (examination)",
        "受ける": "to receive (examination)",
        "勉強": "study",
        "努力": "effort",
        "試験": "exam",
        "成績": "grades, performance",
        "宿題": "homework",
        "学校": "school",
        "大学": "university",
        "先生": "teacher",
        "学生": "student",
        "教科書": "textbook",
        "授業": "class, lesson",
        "合格": "passing (an exam)",
        "辞書": "dictionary",
        "単語": "word, vocabulary",
        "文法": "grammar",
        "読解": "reading comprehension",
        "書く": "to write",
        "話す": "to speak",
        "聞く": "to listen",
        "読む": "to read",
        "理解": "understanding",
        "説明": "explanation",
        "質問": "question",
        "答え": "answer",
        "例文": "example sentence",
        "意味": "meaning",
        "翻訳": "translation",
        "発音": "pronunciation",
        "会話": "conversation",
        "文章": "sentence, text",
        "辞める": "to quit, resign",
        "習う": "to learn",
        "覚える": "to memorize",
        "忘れる": "to forget",
        "復習": "review",
        "予習": "preparation for a lesson",
        "暗記": "memorization",
        "漢字": "kanji",
        "ひらがな": "hiragana",
        "カタカナ": "katakana",
        "筆記": "writing (by hand)",
        "作文": "composition, essay",
        "練習": "practice",
        "課題": "assignment, task",
        "成長": "growth, development",
        "集中": "concentration",
        "努力家": "hardworking person",
        "試す": "to try, test",
        "成功": "success",
        "失敗": "failure"
    ]

    
    var body: some View {
        NavigationStack{
            ZStack {
                
                Color("BackgroundColor").ignoresSafeArea(edges: .all)
                
                VStack {
                    List {
                        ForEach(Array(words.keys), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .fontWeight(.bold)
                                Spacer()
                                Text(words[key] ?? "Unknown")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    Rectangle()
                        .frame(width: 0, height: 60)
                        .foregroundStyle(Color.clear)
                }
                
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        print("Settings tapped")
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .toolbarBackground(Color.black, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .navigationTitle(
                Text("Saved Words")
            )
        }
            
    }
}

#Preview {
    SavedWordsView()
}
