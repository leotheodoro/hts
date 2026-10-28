import CoreText
import Testing

@testable import HTSDesign

@Suite struct FontTests {
    @Test func allBundledFontsRegister() {
        #expect(HTSFonts.register().isEmpty)
    }

    @Test(arguments: HTSTextStyle.all)
    func everyTextStyleResolvesToABundledFont(style: HTSTextStyle) {
        HTSFonts.register()
        let name = style.family.postScriptName(weight: style.weight)
        let font = CTFontCreateWithName(name as CFString, style.size, nil)
        #expect(CTFontCopyPostScriptName(font) as String == name)
    }
}

@Suite struct NotchShapeTests {
    @Test func cutsTopLeftAndBottomRightOnly() {
        let path = NotchShape(cut: 12).path(in: CGRect(x: 0, y: 0, width: 100, height: 50))
        #expect(!path.contains(CGPoint(x: 1, y: 1)))
        #expect(!path.contains(CGPoint(x: 99, y: 49)))
        #expect(path.contains(CGPoint(x: 99, y: 1)))
        #expect(path.contains(CGPoint(x: 1, y: 49)))
    }
}

@Suite struct KanjiSubsetTests {
    @Test func brandKanjiIsInTheBundledSubset() {
        HTSFonts.register()
        let font = CTFontCreateWithName("NotoSerifJP-Black" as CFString, 56, nil)
        let characters = Array("不屈".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        #expect(CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count))
        #expect(glyphs.allSatisfy { $0 != 0 })
    }
}
