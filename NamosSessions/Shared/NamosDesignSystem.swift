import SwiftUI

/// Same tokens as the webapp's design system (Namos's global UI rules: no borders, no
/// shadows, off-white surfaces, whitespace instead of dividers). Lifted straight from
/// the palette table rather than reverse-engineered, so the iOS app and webapp read as
/// one product side by side.
enum NamosColor {
    static let background = Color("NamosBackground")
    static let surface = Color("NamosSurface")
    static let text = Color("NamosText")
    static let mutedText = Color("NamosMutedText")
    static let accent = Color("NamosAccent")
    static let warning = Color("NamosWarning")
}
