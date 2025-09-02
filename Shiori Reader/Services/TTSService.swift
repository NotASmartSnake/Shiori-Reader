import Foundation
import AVFoundation

class TTSService: ObservableObject {
    static let shared = TTSService()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // TTS Settings (can be customized via UserDefaults)
    @Published var preferredGender: AVSpeechSynthesisVoiceGender?
    @Published var speechRate: Float = 0.4 // Slower rate works better for Japanese
    @Published var pitchMultiplier: Float = 1.0
    @Published var volume: Float = 1.0
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Voice Management
    
    func getAvailableJapaneseVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { 
            $0.language == "ja-JP" 
        }
    }
    
    func getPreferredJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let availableVoices = getAvailableJapaneseVoices()
        
        if let preferredGender = preferredGender {
            // Try to find a voice matching the preferred gender
            if let genderMatch = availableVoices.first(where: { $0.gender == preferredGender }) {
                return genderMatch
            }
        }
        
        // Fallback to default Japanese voice
        return AVSpeechSynthesisVoice(language: "ja-JP")
    }
    
    // MARK: - Speech Functions
    
    func speak(text: String, language: String = "ja-JP") {
        guard !text.isEmpty else { return }
        
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Use preferred voice or fallback
        if language == "ja-JP" {
            utterance.voice = getPreferredJapaneseVoice()
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }
        
        // Apply custom settings
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume
        
        speechSynthesizer.speak(utterance)
    }
    
    func speakJapanese(term: String, reading: String? = nil) {
        // Prefer reading for accurate pronunciation, fallback to term
        let textToSpeak = reading?.isEmpty == false ? reading! : term
        speak(text: textToSpeak, language: "ja-JP")
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // Load saved preferences from UserDefaults
        if let genderRaw = UserDefaults.standard.object(forKey: "TTSPreferredGender") as? Int {
            preferredGender = AVSpeechSynthesisVoiceGender(rawValue: genderRaw)
        }
        
        let savedRate = UserDefaults.standard.object(forKey: "TTSSpeechRate") as? Float
        speechRate = savedRate ?? 0.4
        
        let savedPitch = UserDefaults.standard.object(forKey: "TTSPitchMultiplier") as? Float
        pitchMultiplier = savedPitch ?? 1.0
        
        let savedVolume = UserDefaults.standard.object(forKey: "TTSVolume") as? Float
        volume = savedVolume ?? 1.0
    }
    
    func saveSettings() {
        if let preferredGender = preferredGender {
            UserDefaults.standard.set(preferredGender.rawValue, forKey: "TTSPreferredGender")
        } else {
            UserDefaults.standard.removeObject(forKey: "TTSPreferredGender")
        }
        
        UserDefaults.standard.set(speechRate, forKey: "TTSSpeechRate")
        UserDefaults.standard.set(pitchMultiplier, forKey: "TTSPitchMultiplier")
        UserDefaults.standard.set(volume, forKey: "TTSVolume")
    }
    
    func resetToDefaults() {
        preferredGender = nil
        speechRate = 0.4
        pitchMultiplier = 1.0
        volume = 1.0
        saveSettings()
    }
    
    // MARK: - Voice Information
    
    func getVoiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        return voice.name
    }
    
    func getGenderDisplayName(_ gender: AVSpeechSynthesisVoiceGender) -> String {
        switch gender {
        case .male: return "Male"
        case .female: return "Female"
        case .unspecified: return "Unspecified"
        @unknown default: return "Unknown"
        }
    }
}