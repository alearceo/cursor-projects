import Combine
import CoreLocation
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ConditionsViewModel()
    @StateObject private var locationService = LocationService()
    @AppStorage("stridecheck.notifyRunWindows") private var notifyStrongWindows = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            conditionsPane
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
        .tint(.teal)
        .task {
            locationService.requestAccessAndLocation()
        }
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            Task { await vm.loadForCurrentLocation(coordinate) }
        }
    }

    private var conditionsPane: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    brandBlock
                    headerCard
                    locationControls
                    notificationToggle

                    if let cached = vm.snapshot?.cachedAt {
                        offlineBanner(cached)
                    }
                    if let error = vm.errorMessage ?? locationService.lastError {
                        errorBanner(error)
                    }

                    if let snapshot = vm.snapshot {
                        snapshotView(snapshot)
                    } else if vm.isLoading {
                        ProgressView("Loading runner conditions...")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable {
                if let c = locationService.coordinate {
                    await vm.loadForCurrentLocation(c)
                } else if vm.zipInput.count == 5 {
                    await vm.loadForZip()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("StrideCheck")
                .font(.largeTitle.weight(.bold))
            Text("Road conditions for city runners")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location first, zip optional")
                .font(.headline)
            Text("Uses your iPhone location first. Enter a zip only if you need a manual fallback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var locationControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                locationService.requestAccessAndLocation()
            } label: {
                Label("Use Current Location", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            HStack(spacing: 10) {
                TextField("Zip fallback (optional)", text: $vm.zipInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Load") {
                    Task { await vm.loadForZip() }
                }
                .buttonStyle(.bordered)
                .disabled(vm.isLoading || vm.zipInput.count < 5)
            }
        }
    }

    private var notificationToggle: some View {
        Toggle(isOn: $notifyStrongWindows) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strong run alerts")
                    .font(.subheadline.weight(.semibold))
                Text("At most one local notification per ~12h when the run index is high.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: notifyStrongWindows) { _, on in
            if on {
                Task { _ = await RunWindowNotifier.requestAuthorizationIfNeeded() }
            }
        }
    }

    private func offlineBanner(_ date: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline snapshot")
                    .font(.subheadline.weight(.semibold))
                Text("Showing cached data from \(SnapshotCache.formattedSavedAt(date)). Pull to refresh when you are back online.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func snapshotView(_ snap: ConditionsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(snap.placeName).font(.title3).bold()
                Text(String(format: "%.4f, %.4f", snap.latitude, snap.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            runIndexCard(score: snap.score, verdict: snap.verdict, bullets: snap.bullets)
            rowsCard(title: "Wearables & readiness", rows: snap.wearableRows)
            awarenessCard(score: snap.awarenessScore, verdict: snap.awarenessVerdict, bullets: snap.awarenessBullets)

            rowsCard(title: "Right Now", rows: snap.currentRows)
            rowsCard(title: "Air & Comfort", rows: snap.airRows)
            hourlyStrip(snap.hourly)
            alertsSection(snap.alerts)
        }
    }

    private func runIndexCard(score: Int, verdict: String, bullets: [String]) -> some View {
        let tier = RunIndexTier(score: score)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: tier.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Run Index")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tier.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(tier.accentColor.opacity(0.22))
                            .foregroundStyle(tier.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(verdict)
                        .font(.headline)
                }
            }

            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Label(bullet, systemImage: "figure.run")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tier.accentColor.opacity(0.45), lineWidth: 2)
        )
    }

    private func awarenessCard(score: Int, verdict: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(.indigo)
                Text("Route awareness")
                    .font(.subheadline.weight(.semibold))
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(verdict)
                .font(.subheadline)
            ForEach(bullets.prefix(4), id: \.self) { bullet in
                Text("• \(bullet)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("Combines daylight, weather, air, NWS alerts, and optional third-party crime-incident feeds (incomplete, delayed). Not a substitute for judgment, trusted people, or official safety resources.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rowsCard(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.0).foregroundStyle(.secondary)
                    Spacer()
                    Text(row.1).bold()
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func hourlyStrip(_ items: [HourlyDisplay]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next 12 Hours")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        VStack(spacing: 6) {
                            Text(item.timeLabel).font(.caption2.monospacedDigit())
                            Text(item.icon).font(.title3)
                            Text(item.rainChanceLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func alertsSection(_ alerts: [NWSAlert]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Alerts")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            if alerts.isEmpty {
                Text("No active NWS alerts right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(alerts) { alert in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.headline).bold()
                        if let description = alert.description, !description.isEmpty {
                            Text(description)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Route / 511

struct RouteAnd511View: View {
    let coordinate: CLLocationCoordinate2D?
    let stateAbbrev: String?
    let placeName: String?

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            mapLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 1, minHeight: 1)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    route511Card
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { recenterMap() }
        .onChange(of: coordinateKey) { _, _ in recenterMap() }
    }

    private var route511Card: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let placeName {
                Text(placeName)
                    .font(.headline)
            }
            Text("Official state 511 and DOT maps show closures, incidents, and construction. StrideCheck does not draw live 511 geometry yet — open your state link for full layers.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: State511Links.url(forStateAbbrev: stateAbbrev)) {
                Label(
                    stateAbbrev != nil ? "Open state 511 / traveler map" : "Open 511 directory",
                    systemImage: "safari.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var coordinateKey: String {
        guard let c = coordinate else { return "" }
        return "\(c.latitude),\(c.longitude)"
    }

    @ViewBuilder
    private var mapLayer: some View {
        if let c = coordinate {
            Map(position: $position) {
                Marker("StrideCheck area", coordinate: c)
                    .tint(.teal)
            }
            // Flat standard style avoids extra Metal/terrain work that can spam Simulator logs (0×0 drawable, clip warnings).
            .mapStyle(.standard(elevation: .flat))
        } else {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                ContentUnavailableView(
                    "Map needs a location",
                    systemImage: "map",
                    description: Text("Open the Conditions tab and load your area first.")
                )
            }
        }
    }

    private func recenterMap() {
        guard let c = coordinate else { return }
        position = .region(
            MKCoordinateRegion(center: c, latitudinalMeters: 4500, longitudinalMeters: 4500)
        )
    }
}

// MARK: - Run index styling

private enum RunIndexTier {
    case good
    case moderate
    case poor

    init(score: Int) {
        switch score {
        case 80...100: self = .good
        case 60..<80: self = .moderate
        default: self = .poor
        }
    }

    var accentColor: Color {
        switch self {
        case .good: return Color(red: 0.2, green: 0.72, blue: 0.38)
        case .moderate: return Color(red: 0.95, green: 0.76, blue: 0.2)
        case .poor: return Color(red: 0.92, green: 0.32, blue: 0.28)
        }
    }

    var gradient: [Color] {
        switch self {
        case .good:
            return [Color(red: 0.12, green: 0.55, blue: 0.32).opacity(0.35), Color(red: 0.2, green: 0.72, blue: 0.38).opacity(0.12)]
        case .moderate:
            return [Color(red: 0.75, green: 0.55, blue: 0.1).opacity(0.35), Color(red: 0.95, green: 0.76, blue: 0.2).opacity(0.12)]
        case .poor:
            return [Color(red: 0.65, green: 0.15, blue: 0.12).opacity(0.35), Color(red: 0.92, green: 0.32, blue: 0.28).opacity(0.12)]
        }
    }

    var label: String {
        switch self {
        case .good: return "Strong"
        case .moderate: return "Mixed"
        case .poor: return "Tough"
        }
    }
}
