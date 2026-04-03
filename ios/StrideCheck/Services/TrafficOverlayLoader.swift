import CoreLocation
import Foundation

/// Optional GeoJSON (`LineString` / `MultiLineString` inside `Feature` / `FeatureCollection`) for map overlays.
/// Point your own HTTPS URL via `TrafficOverlayGeoJSONURL` in Info.plist / xcconfig when a DOT publishes compatible feeds.
enum TrafficOverlayLoader {
    static func loadPolylines(from url: URL) async -> [[CLLocationCoordinate2D]] {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            return GeoJSONPolylineDecoder.polylines(from: data)
        } catch {
            return []
        }
    }
}

enum GeoJSONPolylineDecoder {
    static func polylines(from data: Data) -> [[CLLocationCoordinate2D]] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var out: [[CLLocationCoordinate2D]] = []
        walk(root, into: &out)
        return out
    }

    private static func walk(_ any: Any, into out: inout [[CLLocationCoordinate2D]]) {
        guard let dict = any as? [String: Any] else {
            if let arr = any as? [Any] {
                arr.forEach { walk($0, into: &out) }
            }
            return
        }
        let type = dict["type"] as? String
        switch type {
        case "FeatureCollection":
            if let features = dict["features"] as? [Any] {
                features.forEach { walk($0, into: &out) }
            }
        case "Feature":
            if let geom = dict["geometry"] {
                walk(geom, into: &out)
            }
        case "LineString":
            if let coords = dict["coordinates"] as? [[Double]] {
                let line = coords.compactMap(toCoord)
                if line.count >= 2 { out.append(line) }
            }
        case "MultiLineString":
            if let multi = dict["coordinates"] as? [[[Double]]] {
                for ring in multi {
                    let line = ring.compactMap(toCoord)
                    if line.count >= 2 { out.append(line) }
                }
            }
        default:
            if let features = dict["features"] as? [Any] { features.forEach { walk($0, into: &out) } }
            if let geometries = dict["geometries"] as? [Any] { geometries.forEach { walk($0, into: &out) } }
        }
    }

    private static func toCoord(_ pair: [Double]) -> CLLocationCoordinate2D? {
        guard pair.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
    }
}
