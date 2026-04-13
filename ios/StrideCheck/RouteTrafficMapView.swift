import MapKit
import SwiftUI
import UIKit

final class CenterStrideCheckAnnotation: MKPointAnnotation {}
final class DOTConditionAnnotation: MKPointAnnotation {}

final class DOTTrafficPolyline: MKPolyline {}
final class StravaRoutePolyline: MKPolyline {}
final class SuggestedRoutePolyline: MKPolyline {}

/// MapKit map with **live Apple traffic** (`showsTraffic`) plus optional DOT and Strava overlays (Options A + C).
struct RouteTrafficMapView: UIViewRepresentable {
    var region: MKCoordinateRegion
    var centerPin: CLLocationCoordinate2D?
    var centerTitle: String
    var dotFeatures: [TrafficOverlayFeature]
    var stravaPolylines: [[CLLocationCoordinate2D]]
    /// MVP suggested out-and-back routes (teal/green); empty hides them.
    var suggestedPolylines: [[CLLocationCoordinate2D]]

    func makeCoordinator() -> Coordinator {
        Coordinator(centerTitle: centerTitle)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsTraffic = true
        map.mapType = .standard
        map.pointOfInterestFilter = .excludingAll
        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.centerTitle = centerTitle
        context.coordinator.sync(
            mapView: mapView,
            region: region,
            centerPin: centerPin,
            dotFeatures: dotFeatures,
            stravaPolylines: stravaPolylines,
            suggestedPolylines: suggestedPolylines
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var centerTitle: String
        private var lastRegionApplied: MKCoordinateRegion?

        init(centerTitle: String) {
            self.centerTitle = centerTitle
        }

        func sync(
            mapView: MKMapView,
            region: MKCoordinateRegion,
            centerPin: CLLocationCoordinate2D?,
            dotFeatures: [TrafficOverlayFeature],
            stravaPolylines: [[CLLocationCoordinate2D]],
            suggestedPolylines: [[CLLocationCoordinate2D]]
        ) {
            if lastRegionApplied == nil || !regionsClose(lastRegionApplied!, region) {
                mapView.setRegion(region, animated: false)
                lastRegionApplied = region
            }

            mapView.removeOverlays(mapView.overlays)
            for ann in mapView.annotations where !(ann is MKUserLocation) {
                mapView.removeAnnotation(ann)
            }

            if let c = centerPin {
                let a = CenterStrideCheckAnnotation()
                a.coordinate = c
                a.title = centerTitle
                mapView.addAnnotation(a)
            }

            for f in dotFeatures {
                switch f {
                case .point(let coord):
                    let a = DOTConditionAnnotation()
                    a.coordinate = coord
                    a.title = "Condition"
                    mapView.addAnnotation(a)
                case .polyline(let coords):
                    guard coords.count >= 2 else { continue }
                    var pts = coords
                    let poly = DOTTrafficPolyline(coordinates: &pts, count: pts.count)
                    mapView.addOverlay(poly)
                }
            }

            for line in stravaPolylines where line.count >= 2 {
                var pts = line
                let poly = StravaRoutePolyline(coordinates: &pts, count: pts.count)
                mapView.addOverlay(poly)
            }

            for line in suggestedPolylines where line.count >= 2 {
                var pts = line
                let poly = SuggestedRoutePolyline(coordinates: &pts, count: pts.count)
                mapView.addOverlay(poly)
            }
        }

        private func regionsClose(_ a: MKCoordinateRegion, _ b: MKCoordinateRegion) -> Bool {
            abs(a.center.latitude - b.center.latitude) < 0.00015
                && abs(a.center.longitude - b.center.longitude) < 0.00015
                && abs(a.span.latitudeDelta - b.span.latitudeDelta) < 0.00005
                && abs(a.span.longitudeDelta - b.span.longitudeDelta) < 0.00005
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                if poly is StravaRoutePolyline {
                    r.strokeColor = UIColor.systemPurple.withAlphaComponent(0.85)
                } else if poly is SuggestedRoutePolyline {
                    r.strokeColor = UIColor.systemGreen.withAlphaComponent(0.88)
                } else {
                    r.strokeColor = UIColor.systemOrange.withAlphaComponent(0.78)
                }
                r.lineWidth = 3
                r.lineCap = .round
                r.lineJoin = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            if annotation is CenterStrideCheckAnnotation {
                let id = "stridecheck.center"
                let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                v.annotation = annotation
                v.markerTintColor = .systemTeal
                v.glyphImage = UIImage(systemName: "figure.run")
                return v
            }

            if annotation is DOTConditionAnnotation {
                let id = "stridecheck.dotpt"
                let v = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
                v.annotation = annotation
                v.markerTintColor = .systemOrange
                v.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
                return v
            }

            return nil
        }
    }
}
