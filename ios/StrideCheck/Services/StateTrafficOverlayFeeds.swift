import CoreLocation
import Foundation

/// Curated **state DOT / Esri** feature layers (Option C). Each value is a layer base URL ending at `FeatureServer/<layerId>` (no `/query`).
///
/// Feeds are queried with a **WGS84 envelope** around the map center. URLs and schemas change; verify periodically and extend the table.
/// Add states by appending entries here (and ensure `StrideCheckHTTPSession` / ATS allow the host if not `*.arcgis.com`).
enum StateTrafficOverlayFeeds {
    private static let layerEndpoints: [String: String] = [
        // Florida public traffic incidents (points / lines vary by release).
        "FL": "https://services1.arcgis.com/O1JpcwDW8sjYuddV/arcgis/rest/services/FloridaTrafficIncidentsPublic/FeatureServer/0",
        // Virginia roadway condition segments (geometry type varies).
        "VA": "https://services1.arcgis.com/J4d1kH3etjxbEIGQ/arcgis/rest/services/VDOT_SystemWideRoadConditions/FeatureServer/0",
        // Washington traveler road closures (verify layer id if empty results).
        "WA": "https://gismaps.wsdot.wa.gov/arcgis/rest/services/Traveler/RoadwayClosures/FeatureServer/0"
    ]

    static func hasRegisteredFeed(forStateAbbrev code: String?) -> Bool {
        guard let c = normalizedCode(code) else { return false }
        return layerEndpoints[c] != nil
    }

    /// Builds `.../query` with `f=geojson` and a geographic envelope (~`spanMeters` across).
    static func geojsonQueryURL(forStateAbbrev code: String?, around center: CLLocationCoordinate2D, spanMeters: Double = 45_000) -> URL? {
        guard let c = normalizedCode(code), let base = layerEndpoints[c], let layerURL = URL(string: base) else { return nil }
        return arcGISGeoJSONQueryURL(layerURL: layerURL, center: center, spanMeters: spanMeters)
    }

    private static func normalizedCode(_ code: String?) -> String? {
        guard let u = code?.uppercased(), u.count == 2 else { return nil }
        return u
    }

    private static func arcGISGeoJSONQueryURL(layerURL: URL, center: CLLocationCoordinate2D, spanMeters: Double) -> URL? {
        let halfLat = (spanMeters / 111_000) / 2
        let cosLat = max(0.2, abs(cos(center.latitude * .pi / 180)))
        let halfLon = (spanMeters / (111_000 * cosLat)) / 2
        let xmin = center.longitude - halfLon
        let ymin = center.latitude - halfLat
        let xmax = center.longitude + halfLon
        let ymax = center.latitude + halfLat
        let geomJSON =
            "{\"xmin\":\(xmin),\"ymin\":\(ymin),\"xmax\":\(xmax),\"ymax\":\(ymax),\"spatialReference\":{\"wkid\":4326}}"

        let queryURL = layerURL.appendingPathComponent("query")
        var comp = URLComponents(url: queryURL, resolvingAgainstBaseURL: false)
        comp?.queryItems = [
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "geometry", value: geomJSON),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "outFields", value: "*"),
            URLQueryItem(name: "resultRecordCount", value: "500")
        ]
        return comp?.url
    }
}
