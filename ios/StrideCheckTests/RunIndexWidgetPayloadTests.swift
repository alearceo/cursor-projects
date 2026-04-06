import XCTest
@testable import StrideCheck

/// Tests for RunIndexWidgetPayload Codable round-trip and RunIndexTierKind banding.
final class RunIndexWidgetPayloadTests: XCTestCase {

    func testTierKindBanding() {
        XCTAssertEqual(RunIndexTierKind(score: 100), .good)
        XCTAssertEqual(RunIndexTierKind(score: 80),  .good)
        XCTAssertEqual(RunIndexTierKind(score: 79),  .moderate)
        XCTAssertEqual(RunIndexTierKind(score: 60),  .moderate)
        XCTAssertEqual(RunIndexTierKind(score: 59),  .poor)
        XCTAssertEqual(RunIndexTierKind(score: 0),   .poor)
    }

    func testPayloadCodableRoundTrip() throws {
        let payload = RunIndexWidgetPayload.placeholder

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(RunIndexWidgetPayload.self, from: encoded)

        XCTAssertEqual(decoded.score,             payload.score)
        XCTAssertEqual(decoded.tierLabel,         payload.tierLabel)
        XCTAssertEqual(decoded.tier,              payload.tier)
        XCTAssertEqual(decoded.placeName,         payload.placeName)
        XCTAssertEqual(decoded.awarenessScore,    payload.awarenessScore)
        XCTAssertEqual(decoded.awarenessTierLabel, payload.awarenessTierLabel)
        XCTAssertEqual(decoded.contextLine,       payload.contextLine)
    }

    func testDefaultDecodeFallbacks() throws {
        // Encode a minimal JSON without optional fields and verify backward-compatible defaults.
        let minimalJSON = """
        {
          "score": 75,
          "verdict": "Good",
          "tierLabel": "Strong",
          "tier": "good",
          "contextLine": "",
          "placeName": "Somewhere",
          "updatedAt": 0,
          "bullets": [],
          "wearableRows": [],
          "currentRows": [],
          "airRows": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(RunIndexWidgetPayload.self, from: minimalJSON)
        XCTAssertEqual(decoded.awarenessScore, 0,  "Default awarenessScore should be 0")
        XCTAssertEqual(decoded.awarenessTierLabel, "—", "Default awarenessTierLabel should be '—'")
    }
}
