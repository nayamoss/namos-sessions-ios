#if os(iOS)
import UIKit
#endif

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Basic Haptics
    
    func selection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    #if os(iOS)
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #else
    enum FeedbackStyle {
        case light, medium, heavy, soft, rigid
    }
    
    func impact(style: FeedbackStyle) {
        // No haptics on macOS
    }
    #endif
    
    #if os(iOS)
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    #else
    enum FeedbackType {
        case success, warning, error
    }
    
    func notification(type: FeedbackType) {
        // No haptics on macOS
    }
    #endif
    
    // MARK: - Semantic Haptics (convenience methods)
    
    /// Soft tap for selections, toggles, and minor interactions
    func tap() {
        #if os(iOS)
        impact(style: .light)
        #endif
    }
    
    /// Medium impact for button presses and confirmations
    func press() {
        #if os(iOS)
        impact(style: .medium)
        #endif
    }
    
    /// Success feedback for saves, completions
    func success() {
        #if os(iOS)
        notification(type: .success)
        #endif
    }
    
    /// Warning feedback for deletes, destructive actions
    func warning() {
        #if os(iOS)
        notification(type: .warning)
        #endif
    }
    
    /// Error feedback for failures
    func error() {
        #if os(iOS)
        notification(type: .error)
        #endif
    }
    
    /// Soft thud for recording start
    func recordStart() {
        #if os(iOS)
        impact(style: .soft)
        #endif
    }
    
    /// Rigid stop for recording end
    func recordStop() {
        #if os(iOS)
        impact(style: .rigid)
        #endif
    }
}
