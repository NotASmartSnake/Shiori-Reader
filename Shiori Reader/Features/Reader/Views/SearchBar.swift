//
//  SearchBar.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 4/4/25.
//

import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var onSearchButtonClicked: (() -> Void)? = nil
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        var onSearchButtonClicked: (() -> Void)?
        
        init(text: Binding<String>, onSearchButtonClicked: (() -> Void)?) {
            _text = text
            self.onSearchButtonClicked = onSearchButtonClicked
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            onSearchButtonClicked?()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, onSearchButtonClicked: onSearchButtonClicked)
    }
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = "Search in book"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.showsCancelButton = false
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context) {
        uiView.text = text
    }
}
