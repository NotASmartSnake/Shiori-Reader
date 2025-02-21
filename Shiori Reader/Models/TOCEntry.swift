//
//  TOCEntry.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation
import SwiftUI

struct TOCEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    let label: String
    let href: String
    let level: Int
    var children: [TOCEntry]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
