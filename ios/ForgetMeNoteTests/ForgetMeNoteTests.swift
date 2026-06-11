import Testing
import SwiftUI
@testable import ForgetMeNote

@Suite("Data model smoke tests")
struct ForgetMeNoteTests {

    @Test("Rectangle round-trips through Gson-compatible JSON")
    func rectangleJSONRoundTrip() throws {
        let original = Rectangle(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let encoded = try #require(original.encodeAsJSONString())
        let decoded = try #require(Rectangle.decode(encoded))
        #expect(decoded == original)
    }

    @Test("ImageItem.isRoom mirrors filePath presence")
    func imageItemIsRoom() {
        let room = ImageItem(name: "Living Room")
        #expect(room.isRoom)

        let item = ImageItem(name: "Photo", filePath: "/tmp/x.jpg")
        #expect(!item.isRoom)
    }

    @Test("AppSettings defaults match the Android v12 schema")
    func appSettingsDefaults() {
        let s = AppSettings()
        #expect(s.id == 1)
        #expect(s.childRectangleTransparency == 0.25)
        #expect(s.childRectangleBorderWidth == 3.0)
        #expect(s.childRectangleBorderTransparency == 0.4)
        #expect(s.enableTagsListEdit)
        #expect(s.checkOrphanedImages)
        #expect(s.lastOrphanedCheck == 0)
        #expect(s.searchThroughCollapsedImages)
        #expect(s.roomBackgroundColor == 0xFF6750A4)
        #expect(s.roomTextColor == 0xFFFFFFFF)
        #expect(s.updatedHighlightColor == 0xFFFF9800)
        #expect(s.updatedHighlightPercentage == 0.2)
        #expect(s.showUpdatedBadge)
        #expect(!s.updatedRemindersEnabled)
        #expect(s.updatedRemindersFrequency == "weekly")
        #expect(s.scaleDownPhotos)
        #expect(s.scaleDownMinWidth == 740)
    }

    @Test("ARGB packing round-trips through Color")
    func argbRoundTrip() {
        let argb: Int64 = 0xFFFF9800 // orange
        let color = Color(argb: argb)
        let back = color.argbInt64
        // sRGB float round-trip can lose 1 LSB per channel; assert per-channel within 1.
        let backU = UInt32(truncatingIfNeeded: back)
        let origU = UInt32(truncatingIfNeeded: argb)
        for shift in stride(from: 0, through: 24, by: 8) {
            let bc = Int((backU >> shift) & 0xFF)
            let oc = Int((origU >> shift) & 0xFF)
            #expect(abs(bc - oc) <= 1, "channel @\(shift) differs: \(bc) vs \(oc)")
        }
    }
}
