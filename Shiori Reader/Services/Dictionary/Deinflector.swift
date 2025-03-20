//
//  Deinflector.swift
//  Shiori Reader
//
//  Created by Russell Graviet on 3/20/25.
//

import Foundation

// Model for deinflection rule variants
struct DeinflectionVariant: Decodable {
    let kanaIn: String
    let kanaOut: String
    let rulesIn: [String]
    let rulesOut: [String]
}

// Model for deinflection results
struct DeinflectionResult {
    let term: String
    let rules: Int
    let reasons: [String]
}

class Deinflector {
    // Maps rule types to bit flags
    private static let ruleTypes: [String: Int] = [
        "v1": 0b00000001,     // Verb ichidan
        "v5": 0b00000010,     // Verb godan
        "vs": 0b00000100,     // Verb suru
        "vk": 0b00001000,     // Verb kuru
        "vz": 0b00010000,     // Verb zuru
        "adj-i": 0b00100000,  // Adjective i
        "iru": 0b01000000     // Intermediate -iru endings
    ]
    
    private let reasons: [(String, [[Any]])]
    
    init(reasons: [String: [DeinflectionVariant]]) {
        self.reasons = Deinflector.normalizeReasons(reasons)
    }
    
    // Convert rule strings to bit flags
    private static func rulesToRuleFlags(_ rules: [String]) -> Int {
        var value = 0
        for rule in rules {
            if let ruleBits = ruleTypes[rule] {
                value |= ruleBits
            }
        }
        return value
    }
    
    // Normalize the reasons data structure, allowing for checking rule strings with bitwise AND operations
    private static func normalizeReasons(_ reasons: [String: [DeinflectionVariant]]) -> [(String, [[Any]])] {
        var normalizedReasons: [(String, [[Any]])] = []
        
        for (reason, reasonInfo) in reasons {
            var variants: [[Any]] = []
            
            for variant in reasonInfo {
                variants.append([
                    variant.kanaIn,
                    variant.kanaOut,
                    rulesToRuleFlags(variant.rulesIn),
                    rulesToRuleFlags(variant.rulesOut)
                ])
            }
            
            normalizedReasons.append((reason, variants))
        }
        
        return normalizedReasons
    }
    
    // Create a deinflection result
    private func createDeinflection(term: String, rules: Int, reasons: [String]) -> DeinflectionResult {
        return DeinflectionResult(term: term, rules: rules, reasons: reasons)
    }
    
    // Process deinflection for a given word
    func deinflect(_ source: String) -> [DeinflectionResult] {
        var results = [createDeinflection(term: source, rules: 0, reasons: [])]
        
        for i in 0..<results.count {
            let result = results[i]
            let term = result.term
            let rules = result.rules
            let reasonsList = result.reasons
            
            for (reason, variants) in self.reasons {
                for variant in variants {
                    let kanaIn = variant[0] as! String
                    let kanaOut = variant[1] as! String
                    let rulesIn = variant[2] as! Int
                    let rulesOut = variant[3] as! Int
                    
                    if (rules != 0 && (rules & rulesIn) == 0) || !term.hasSuffix(kanaIn) || (term.count - kanaIn.count + kanaOut.count) <= 0 {
                        continue
                    }
                    
                    let newTerm = term.prefix(term.count - kanaIn.count) + kanaOut
                    var newReasons = reasonsList
                    newReasons.insert(reason, at: 0)
                    
                    results.append(createDeinflection(term: String(newTerm), rules: rulesOut, reasons: newReasons))
                }
            }
        }
        
        return results
    }
    
    // Load deinflection rules from JSON
    static func loadFromJSON(_ jsonData: Data) -> Deinflector? {
        do {
            let decoder = JSONDecoder()
            let reasons = try decoder.decode([String: [DeinflectionVariant]].self, from: jsonData)
            return Deinflector(reasons: reasons)
        } catch {
            print("Error loading deinflection rules: \(error)")
            return nil
        }
    }
}
