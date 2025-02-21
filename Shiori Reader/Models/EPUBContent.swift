//
//  EPUBContent.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

import Foundation

struct EPUBContent: Codable {
    var chapters: [Chapter]
    var metadata: EPUBMetadata
    var images: [String: Data]
    var spineOrder: [String]
}
