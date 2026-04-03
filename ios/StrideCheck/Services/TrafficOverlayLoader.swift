import CoreLocation
import Foundation

/// Point or polyline geometry extracted from agency GeoJSON (ArcGIS `f=geojson`, static GeoJSON, etc.).
enum TrafficOverlayFeature {
    case point(CLLocationCoordinate2D)
    case polyline([CLLocationCoordinate2D])
}

/// Loads DOT / 511-style GeoJSON for map overlays (Option C). Uses `StrideCheckHTTPSession` for corporate TLS.
enum TrafficOverlayLoader {
    static func loadFeatures(from url: URL) async -> [TrafficOverlayFeature] {
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await StrideCheckHTTPSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            return GeoJSONTrafficDecoder.features(from: data)
        } catch {
            return []
        }
    }
}

// MARK: - GeoJSON (FeatureCollection, ArcGIS-style)

enum GeoJSONTrafficDecoder {
    static func features(from data: Data) -> [TrafficOverlayFeature] {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var out: [TrafficOverlayFeature] = []
        walk(root, into: &out)
        return out
    }

    private static func walk(_ any: Any, into out: inout [TrafficOverlayFeature]) {
        guard let dict = any as? [String: Any] else {
            if let arr = any as? [Any] { arr.forEach { walk($0, into: &out) } }
            return
        }
        let type = dict["type"] as? String
        switch type {
        case "FeatureCollection":
            if let features = dict["features"] as? [Any] { features.forEach { walk($0, into: &out) } }
        case "Feature":
            if let geom = dict["geometry"] { walk(geom, into: &out) }
        case "GeometryCollection":
            if let geoms = dict["geometries"] as? [Any] { geoms.forEach { walk($0, into: &out) } }
        case "Point":
            if let coords = dict["coordinates"] as? [Double], let p = toPoint(coords) {
                out.append(.point(p))
            }
        case "MultiPoint":
            if let multi = dict["coordinates"] as? [[Double]] {
                for c in multi {
                    if let p = toPoint(c) { out.append(.point(p)) }
                }
            }
        case "LineString":
            if let coords = dict["coordinates"] as? [[Double]] {
                let line = coords.compactMap(toCoord)
                if line.count >= 2 { out.append(.polyline(line)) }
            }
        case "MultiLineString":
            if let multi = dict["coordinates"] as? [[[Double]]] {
                for ring in multi {
                    let line = ring.compactMap(toCoord)
                    if line.count >= 2 { out.append(.polyline(line)) }
                }
            }
        case "Polygon":
            if let rings = dict["coordinates"] as? [[[Double]]], let outer = rings.first {
                let line = outer.compactMap(toCoord)
                if line.count >= 2 { out.append(.polyline(line)) }
            }
        case "MultiPolygon":
            if let multip = dict["coordinates"] as? [[[[Double]]]] {
                for poly in multip {
                    if let outer = poly.first {
                        let line = outer.compactMap(toCoord)
                        if line.count >= 2 { out.append(.polyline(line)) }
                    }
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

    private static func toPoint(_ pair: [Double]) -> CLLocationCoordinate2D? {
        toCoord(pair)
    }
}
