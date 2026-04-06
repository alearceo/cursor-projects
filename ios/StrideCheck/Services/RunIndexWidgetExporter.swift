import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum RunIndexWidgetExporter {
    /// Publishes the latest snapshot for the Run Index widget and asks WidgetKit to reload.
    static func publish(_ snapshot: ConditionsSnapshot) {
        let tier = RunIndexTier(score: snapshot.score)
        let payload = RunIndexWidgetPayload(
            score: snapshot.score,
            verdict: snapshot.verdict,
            tierLabel: tier.label,
            tier: RunIndexTierKind(score: snapshot.score),
            contextLine: RunIndexWidgetContextLine.build(from: snapshot),
            placeName: snapshot.placeName,
            updatedAt: Date(),
            bullets: snapshot.bullets,
            wearableRows: snapshot.wearableRows.map { WidgetRowPair(key: $0.0, value: $0.1) },
            currentRows: snapshot.currentRows.map { WidgetRowPair(key: $0.0, value: $0.1) },
            airRows: snapshot.airRows.map { WidgetRowPair(key: $0.0, value: $0.1) }
        )
        RunIndexWidgetPayload.save(payload)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        #endif
    }
}
