import CoreLocation
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var conditionsReloadCenter = ConditionsReloadCenter.shared
    @StateObject private var vm = ConditionsViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var whoopLink = WhoopLinkViewModel()
    @StateObject private var garminLink = GarminLinkViewModel()
    @StateObject private var stravaLink = StravaLinkViewModel()
    @State private var selectedTab = 0
    /// Throttles refetch when the scene becomes active (returning from background). Seeded in `.task` so cold launch does not immediately duplicate `onChange(.active)`.
    @State private var lastForegroundConditionsRefreshAt = Date(timeIntervalSince1970: 0)

    private static let foregroundConditionsRefreshMinInterval: TimeInterval = 45

    var body: some View {
        TabView(selection: $selectedTab) {
            ConditionsTabView(vm: vm, locationService: locationService)
                .tabItem { Label("Conditions", systemImage: "figure.run") }
                .tag(0)

            RouteAnd511View(
                coordinate: vm.snapshot.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
                stateAbbrev: vm.snapshot?.stateAbbrev,
                placeName: vm.snapshot?.placeName
            )
            .tabItem { Label("Route & 511", systemImage: "map") }
            .tag(1)
        }
        .environmentObject(whoopLink)
        .environmentObject(garminLink)
        .environmentObject(stravaLink)
        .tint(.teal)
        .task {
            lastForegroundConditionsRefreshAt = Date()
            locationService.requestAccessAndLocation()
            whoopLink.refreshConnectionState()
            garminLink.refreshConnectionState()
            stravaLink.refreshConnectionState()
        }
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            Task { await vm.loadForCurrentLocation(coordinate) }
        }
        .onChange(of: conditionsReloadCenter.token) { _, _ in
            Task { await reloadConditionsSnapshotIfPossible() }
        }
        .onOpenURL { url in
            guard url.scheme == "stridecheck", url.host == "run-index" else { return }
            selectedTab = 0
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            let now = Date()
            guard now.timeIntervalSince(lastForegroundConditionsRefreshAt) >= Self.foregroundConditionsRefreshMinInterval else {
                return
            }
            lastForegroundConditionsRefreshAt = now
            Task { await reloadConditionsSnapshotIfPossible() }
        }
    }

    private func reloadConditionsSnapshotIfPossible() async {
        if let c = locationService.coordinate {
            await vm.loadForCurrentLocation(c)
        } else if vm.zipInput.count == 5 {
            await vm.loadForZip()
        }
    }
}
