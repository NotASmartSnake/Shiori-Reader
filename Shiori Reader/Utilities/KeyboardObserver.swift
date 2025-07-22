import SwiftUI
import Combine

class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible = false
    @Published var keyboardHeight: CGFloat = 0
    @Published var animationDuration: Double = 0.25
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe keyboard will show notification
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                self?.isKeyboardVisible = true
                
                // Get keyboard height and animation duration
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                   let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                    self?.keyboardHeight = keyboardFrame.height
                    self?.animationDuration = duration
                }
            }
            .store(in: &cancellables)
        
        // Observe keyboard will hide notification
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.isKeyboardVisible = false
                self?.keyboardHeight = 0
            }
            .store(in: &cancellables)
    }
}
