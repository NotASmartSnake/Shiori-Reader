//
//  EPUBMetadata.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 2/20/25.
//

struct EPUBMetadata: Codable {
    let title: String
    let author: String
    let language: String
    var publisher: String?
    var publicationDate: String?
    var rights: String?
    var identifier: String?
    
    init(title: String, author: String, language: String,
         publisher: String? = nil, publicationDate: String? = nil,
         rights: String? = nil, identifier: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
        self.publisher = publisher
        self.publicationDate = publicationDate
        self.rights = rights
        self.identifier = identifier
    }
}
