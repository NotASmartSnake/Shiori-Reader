//
//  FileTypeExtensions.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/29/25.
//

import UniformTypeIdentifiers

extension UTType {
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
}
