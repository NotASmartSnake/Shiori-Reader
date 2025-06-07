//
//  Deinflector.swift
//  Shiori Reader
//
//  Enhanced version with rule variants and better debugging
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
    // Maps rule types to bit flags - matches Immersion Reader exactly
    private static let ruleTypes: [String: Int] = [
        "v1": 1,        // Verb ichidan
        "v5": 2,        // Verb godan  
        "vs": 4,        // Verb suru
        "vk": 8,        // Verb kuru
        "vz": 16,       // Verb zuru
        "adj-i": 32,    // Adjective i
        "iru": 64       // Intermediate -iru endings
    ]
    
    private let reasons: [(String, [[Any]])]
    private var debugMode: Bool
    
    init(reasons: [String: [DeinflectionVariant]], debugMode: Bool = false) {
        self.reasons = Deinflector.normalizeReasons(reasons)
        self.debugMode = debugMode
    }
    
    // Enhanced rule processing that handles variants like v5r -> v5, v1s -> v1
    private static func extractBaseRule(_ rule: String) -> String {
        // Direct match
        if ruleTypes.keys.contains(rule) {
            return rule
        }
        
        // v1, v5, vs, vk, vz (2 characters)
        if rule.count >= 2 && ruleTypes.keys.contains(String(rule.prefix(2))) {
            return String(rule.prefix(2))
        }
        
        // iru (3 characters)  
        if rule.count >= 3 && ruleTypes.keys.contains(String(rule.prefix(3))) {
            return String(rule.prefix(3))
        }
        
        // adj-i (5 characters)
        if rule.count >= 5 && ruleTypes.keys.contains(String(rule.prefix(5))) {
            return String(rule.prefix(5))
        }
        
        return rule
    }
    
    // Convert rule strings to bit flags with enhanced rule handling
    private static func rulesToRuleFlags(_ rules: [String]) -> Int {
        var value = 0
        for rule in rules {
            let baseRule = extractBaseRule(rule)
            if let ruleBits = ruleTypes[baseRule] {
                value |= ruleBits
            }
        }
        return value
    }
    
    // Helper to convert rule flags back to string names for debugging
    private static func ruleFlagsToStrings(_ flags: Int) -> [String] {
        var result: [String] = []
        for (ruleName, ruleFlag) in ruleTypes {
            if (flags & ruleFlag) != 0 {
                result.append(ruleName)
            }
        }
        return result
    }
    
    // Normalize the reasons data structure
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
    
    // Main deinflection method - matches Immersion Reader logic exactly
    func deinflect(_ source: String) -> [DeinflectionResult] {
        var results = [createDeinflection(term: source, rules: 0, reasons: [])]
        
        if debugMode {
            print("🔍 [Deinflector] Starting deinflection for: '\(source)'")
        }
        
        var i = 0
        while i < results.count {
            let result = results[i]
            let term = result.term
            let rules = result.rules
            let reasonsList = result.reasons
            
            if debugMode && i > 0 {
                let rulesStrings = Deinflector.ruleFlagsToStrings(rules)
                print("🔄 [Step \(i)] Processing: '\(term)' with rules: \(rulesStrings)")
            }
            
            for (reason, variants) in self.reasons {
                for variant in variants {
                    let kanaIn = variant[0] as! String
                    let kanaOut = variant[1] as! String
                    let rulesIn = variant[2] as! Int
                    let rulesOut = variant[3] as! Int
                    
                    // Rule validation - matches Immersion Reader exactly
                    if (rules != 0 && (rules & rulesIn) == 0) ||
                       !term.hasSuffix(kanaIn) ||
                       (term.count - kanaIn.count + kanaOut.count) <= 0 {
                        continue
                    }
                    
                    let newTerm = term.prefix(term.count - kanaIn.count) + kanaOut
                    var newReasons = [reason] + reasonsList // Prepend new reason
                    
                    if debugMode {
                        let rulesOutStrings = Deinflector.ruleFlagsToStrings(rulesOut)
                        print("   ✅ Applied '\(reason)': '\(term)' → '\(newTerm)' (rules: \(rulesOutStrings))")
                    }
                    
                    results.append(createDeinflection(
                        term: String(newTerm),
                        rules: rulesOut,
                        reasons: newReasons
                    ))
                }
            }
            
            i += 1
        }
        
        if debugMode {
            print("🔍 [Deinflector] Generated \(results.count) total forms for '\(source)'")
            for (index, result) in results.enumerated() {
                if index == 0 {
                    print("   \(index): '\(result.term)' (original)")
                } else {
                    print("   \(index): '\(result.term)' via: \(result.reasons.joined(separator: " ← "))")
                }
            }
        }
        
        return results
    }
    
    // Convenience method to enable debug mode for specific words
    func deinflectWithDebug(_ source: String) -> [DeinflectionResult] {
        let originalDebugMode = self.debugMode
        self.debugMode = true
        let results = deinflect(source)
        self.debugMode = originalDebugMode
        return results
    }
    
    // Load deinflection rules from JSON
    static func loadFromJSON(_ jsonData: Data, debugMode: Bool = false) -> Deinflector? {
        do {
            let decoder = JSONDecoder()
            let reasons = try decoder.decode([String: [DeinflectionVariant]].self, from: jsonData)
            return Deinflector(reasons: reasons, debugMode: debugMode)
        } catch {
            print("Error loading deinflection rules: \(error)")
            return nil
        }
    }
}
