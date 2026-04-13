import CoreLocation
import Foundation

/// Decodes Google-encoded polylines (Strava `summary_polyline` / `polyline` fields).
enum EncodedPolylineDecoder {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        var lat = 0
        var lng = 0
        let scalars = Array(encoded.unicodeScalars)
        var i = 0
        let n = scalars.count
        while i < n {
            var result = 0
            var shift = 0
            var b: UInt32
            repeat {
                guard i < n else { return coordinates }
                b = scalars[i].value - 63
                i += 1
                result |= Int(b & 0x1F) << shift
                shift += 5
            } while b >= 0x20
            let dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dlat

            result = 0
            shift = 0
            repeat {
                guard i < n else { return coordinates }
                b = scalars[i].value - 63
                i += 1
                result |= Int(b & 0x1F) << shift
                shift += 5
            } while b >= 0x20
            let dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dlng

            coordinates.append(
                CLLocationCoordinate2D(latitude: Double(lat) / 100_000, longitude: Double(lng) / 100_000)
            )
        }
        return coordinates
    }
}
