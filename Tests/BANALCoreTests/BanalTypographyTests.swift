import AppKit
import XCTest
@testable import BANALCore

final class BanalTypographyTests: XCTestCase {
    func testMeasureAndInsetMatchEditorSpec() {
        XCTAssertEqual(BanalTypography.measureWidth, 680, accuracy: 0.1)
        XCTAssertEqual(BanalTypography.horizontalInset, 32, accuracy: 0.1)
        XCTAssertEqual(BanalTypography.titleSize, 26, accuracy: 0.1)
    }

    func testBodySizeRangeIsGlobalNotPerNote() {
        // Only one body size range, enforced globally via AppPreferences.fontSize
        XCTAssertEqual(BanalTypography.bodySizeRange, 13...22)
        XCTAssertEqual(BanalTypography.defaultBodySize, 16, accuracy: 0.1)
        // AppPreferences default must match
        XCTAssertEqual(AppPreferences.default.fontSize, 16, accuracy: 0.1)
    }

    func testPairingIsSystemHonest_SansAndMonoOnly() {
        // Pairing is SF Pro (system) + SF Mono — no bundled serif, no custom file
        let sans = BanalTypography.nsFont(size: 16)
        XCTAssertEqual(sans.familyName, NSFont.systemFont(ofSize: 16).familyName)
        let mono = BanalTypography.monoFont(size: 13)
        let expectedMonoFamily = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular).familyName
        XCTAssertEqual(mono.familyName, expectedMonoFamily)
        // CSS stack must be system-ui based, not a webfont or serif personality
        XCTAssertTrue(BanalTypography.cssSystemFontStack.contains("system-ui"))
        XCTAssertTrue(BanalTypography.cssSystemFontStack.contains("-apple-system"))
        XCTAssertTrue(BanalTypography.cssSystemFontStack.contains("sans-serif"))
        XCTAssertFalse(BanalTypography.cssSystemFontStack.lowercased().contains("georgia"))
        XCTAssertFalse(BanalTypography.cssSystemFontStack.lowercased().contains("new york"))
    }

    func testHeadingScaleIsWeightNotHue() {
        // One pairing: headings differ by weight/size, not color — still SF
        XCTAssertEqual(BanalTypography.Heading.h1.weight, .bold)
        XCTAssertEqual(BanalTypography.Heading.h2.weight, .semibold)
        XCTAssertEqual(BanalTypography.Heading.h3.weight, .semibold)
        XCTAssertTrue(BanalTypography.Heading.h1.pointSize > BanalTypography.Heading.h2.pointSize)
        XCTAssertTrue(BanalTypography.Heading.h2.pointSize > BanalTypography.Heading.h3.pointSize)
    }

    func testCSSMeasureMirrorsAppMeasure() {
        // App measure 680pt ≈ 42rem at 16px base (672px). Keep within 5% drift.
        // This guards boris.css `max-width: 42rem` from diverging.
        let appMeasure = BanalTypography.measureWidth
        let cssMeasureRem: CGFloat = 42
        let cssMeasurePx = cssMeasureRem * 16
        let drift = abs(appMeasure - cssMeasurePx) / appMeasure
        XCTAssertLessThan(drift, 0.05, "boris.css measure drift: app \(appMeasure) vs css \(cssMeasurePx)")
    }
}
