import CoreText
import SwiftUI

/// The hand-drawn title font (ZCOOL KuaiLe), bundled and registered at launch.
/// Used for titles and buttons only; everything else uses the system font.
enum AppFont {
    static let handwrittenName = "ZCOOLKuaiLe-Regular"

    static func register() {
        guard let url = Bundle.main.url(forResource: handwrittenName, withExtension: "ttf") else {
            assertionFailure("Missing \(handwrittenName).ttf in bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) // 登记字体，.process表示只在乎当前进app进程内有效
    }
}

// 扩展 Font 类型，添加手写体字体支持
extension Font {
    /// ZCOOL KuaiLe at a design size, scaled with Dynamic Type relative to `textStyle`.
    static func handwritten(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title) -> Font {
        Font.custom(AppFont.handwrittenName, size: size, relativeTo: textStyle)
    }
}
