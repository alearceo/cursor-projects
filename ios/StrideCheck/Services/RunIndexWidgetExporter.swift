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
            updatedAt: Date()
        )
        RunIndexWidgetPayload.save(payload)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "RunIndexNow")
        #endif
    }
}
