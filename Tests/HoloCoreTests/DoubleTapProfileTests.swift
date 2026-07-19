import XCTest
@testable import HoloCore

final class DoubleTapProfileTests: XCTestCase {
    func testZoneConfigurationRoundTripsDoubleTapAction() throws {
        let config = ZoneConfiguration(
            zone: .leftTop,
            action: ZoneActionConfiguration(kind: .sound),
            doubleTapAction: ZoneActionConfiguration(kind: .copyText, text: "hello")
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ZoneConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.doubleTapAction?.kind, .copyText)
        XCTAssertEqual(decoded.doubleTapAction?.text, "hello")
    }

    func testLegacyZoneConfigurationDecodesWithoutDoubleTap() throws {
        // A pre-gesture profile: no doubleTapAction key present.
        let json = Data("""
        {"zone":0,"action":{"kind":"sound","soundName":"Tink","text":""}}
        """.utf8)
        let decoded = try JSONDecoder().decode(ZoneConfiguration.self, from: json)
        XCTAssertNil(decoded.doubleTapAction)
        XCTAssertEqual(decoded.zone, .leftTop)
        XCTAssertEqual(decoded.action.kind, .sound)
    }

    func testNilDoubleTapActionIsOmittedWhenEncoded() throws {
        let config = ZoneConfiguration(zone: .rightBottom, action: ZoneActionConfiguration(kind: .none))
        let data = try JSONEncoder().encode(config)
        let string = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(string.contains("doubleTapAction"), "nil double-tap action should not be written")
    }
}
