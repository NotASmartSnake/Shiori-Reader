//
//  DictionaryUtils.swift
//  Shiori Reader
//
//  Created by Claude on 4/16/25.
//

import Foundation

extension DictionaryManager {
    // Convenience method to access available dictionaries
    static func getAvailableDictionaries() -> [DictionaryInfo] {
        return [
            DictionaryInfo(
                id: "jmdict",
                name: "JMdict",
                description: "Japanese-English dictionary",
                isBuiltIn: true,
                isEnabled: true,
                canDisable: false
            )
        ]
    }
}
