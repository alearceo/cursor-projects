import Combine
import CoreLocation
import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ConditionsViewModel()
    @StateObject private var locationService = LocationService()
    @StateObject private var whoopLink = WhoopLinkViewModel()
    @StateObject private var garminLink = GarminLinkViewModel()
    @StateObject private var stravaLink = StravaLinkViewModel()
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
        .environmentObject(whoopLink)
        .environmentObject(garminLink)
        .environmentObject(stravaLink)
        .tint(.teal)
        .task {
            locationService.requestAccessAndLocation()
            whoopLink.refreshConnectionState()
            garminLink.refreshConnectionState()
            stravaLink.refreshConnectionState()
        }
        .onReceive(locationService.$coordinate.compactMap { $0 }) { coordinate in
            Task { await vm.loadForCurrentLocation(coordinate) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .strideCheckReloadConditionsSnapshot)) { _ in
            Task { await reloadConditionsSnapshotIfPossible() }
        }
        .onOpenURL { url in
            guard url.scheme == "stridecheck" else { return }
            if url.host == "run-index" {
                selectedTab = 0
            }
        }
    }

    /// Refetches conditions (including wearable run index inputs) after Data sources or Whoop connection changes.
    private func reloadConditionsSnapshotIfPossible() async {
        if let c = locationService.coordinate {
            await vm.loadForCurrentLocation(c)
        } else if vm.zipInput.count == 5 {
            await vm.loadForZip()
        }
    }

    private var conditionsPane: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    brandBlock
                    headerCard
                    dataSourcesLinkCard
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
            .overlay(alignment: .top) {
                TopEdgeFrostFade(style: .groupedScroll)
                    .ignoresSafeArea(edges: .top)
            }
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

    private var dataSourcesLinkCard: some View {
        NavigationLink {
            WearableDataSourcesView()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data sources for run index")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Apple Health, Whoop, Oura — choose what affects your score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
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

    private func runIndexDataSourcesHintBanner() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.slash")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run index needs a data source")
                        .font(.subheadline.weight(.semibold))
                    Text("Apple Health isn’t contributing (access off, denied, or no HRV/sleep/activity yet), and Whoop/Oura aren’t turned on for the run index. Use Data sources to allow Health or enable a wearable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                WearableDataSourcesView()
            } label: {
                Text("Open Data sources")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
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

            if snap.showRunIndexDataSourcesHint {
                runIndexDataSourcesHintBanner()
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

// MARK: - Top edge fade (matches Route tab `ultraThinMaterial` footer)

private enum TopEdgeFrostFadeStyle {
    /// Scroll content under status bar: tint with grouped background then frosted mask.
    case groupedScroll
    /// Map under status bar: frost only (same material as `route511Card`).
    case map
}

/// Gradient-style transition so content sliding under the status bar / Dynamic Island softens like the bottom sheet.
/// Vertical extent is tuned to approximate the Route tab bottom `ultraThinMaterial` card so status-bar chrome stays readable.
private struct TopEdgeFrostFade: View {
    var style: TopEdgeFrostFadeStyle

    var body: some View {
        GeometryReader { geo in
            let fadeHeight = geo.safeAreaInsets.top + 56
            let materialTail: CGFloat = 40
            let groupedTintTail: CGFloat = 18
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    if style == .groupedScroll {
                        LinearGradient(
                            colors: [
                                Color(uiColor: .systemGroupedBackground),
                                Color(uiColor: .systemGroupedBackground).opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeHeight + groupedTintTail)
                    }

                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: fadeHeight + materialTail)
                        .mask(
                            LinearGradient(
                                colors: [.black, .black.opacity(0.92), .black.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .frame(height: fadeHeight + materialTail)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Route / 511

struct RouteAnd511View: View {
    let coordinate: CLLocationCoordinate2D?
    let stateAbbrev: String?
    let placeName: String?

    @EnvironmentObject private var stravaLink: StravaLinkViewModel
    @AppStorage(StravaMapOverlayPreferences.showRoutesOnMapKey) private var showStravaRoutesOnMap = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
    )
    @State private var dotOverlayFeatures: [TrafficOverlayFeature] = []
    @State private var stravaPolylines: [[CLLocationCoordinate2D]] = []
    @State private var workoutIntent: WorkoutRouteIntent = .easy
    @State private var suggestionRuns: [SuggestedRouteRun] = []
    @State private var selectedSuggestionId: UUID?
    @State private var isLoadingSuggestions = false
    @State private var suggestionError: String?

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
                .overlay(alignment: .top) {
                    TopEdgeFrostFade(style: .map)
                        .ignoresSafeArea(edges: .top)
                }
        }
        .onAppear {
            recenterMap()
            stravaLink.refreshConnectionState()
        }
        .onChange(of: coordinateKey) { _, _ in
            recenterMap()
            suggestionRuns = []
            selectedSuggestionId = nil
            suggestionError = nil
        }
        .task(id: overlayTaskKey) { await loadStateAgencyOverlay() }
        .task(id: stravaTaskKey) { await loadStravaRoutes() }
    }

    private var stravaTaskKey: String {
        "\(stravaLink.isConnected)|\(showStravaRoutesOnMap)|\(stravaLink.mapDataRefreshGeneration)"
    }

    private var overlayTaskKey: String {
        "\(coordinateKey)|\(stateAbbrev ?? "")"
    }

    private func loadStateAgencyOverlay() async {
        guard let c = coordinate else {
            dotOverlayFeatures = []
            return
        }
        guard let url = StateTrafficOverlayFeeds.geojsonQueryURL(forStateAbbrev: stateAbbrev, around: c) else {
            dotOverlayFeatures = []
            return
        }
        dotOverlayFeatures = await TrafficOverlayLoader.loadFeatures(from: url)
    }

    private func loadStravaRoutes() async {
        guard stravaLink.isConnected, showStravaRoutesOnMap else {
            stravaPolylines = []
            return
        }
        do {
            stravaPolylines = try await StravaAPIClient.recentRunPolylines()
        } catch {
            stravaPolylines = []
        }
    }

    private var route511Card: some View {
        VStack(alignment: .leading, spacing: 12) {
            routeSuggestionCard
            stravaCard
            if let placeName {
                Text(placeName)
                    .font(.headline)
            }
            Text(overlayCaption)
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

    private var routeSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested routes (beta)")
                .font(.subheadline.weight(.semibold))
            Text(workoutIntent.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Picker("Workout type", selection: $workoutIntent) {
                ForEach(WorkoutRouteIntent.allCases) { intent in
                    Text(intent.displayTitle).tag(intent)
                }
            }
            .pickerStyle(.segmented)
            Button {
                Task { await loadRouteSuggestions() }
            } label: {
                HStack {
                    if isLoadingSuggestions {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Find routes near here")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(coordinate == nil || isLoadingSuggestions)
            Text("Uses Apple walking directions and open elevation data. Not turn-by-turn navigation — verify roads and traffic yourself.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let suggestionError {
                Text(suggestionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if suggestionRuns.isEmpty, !isLoadingSuggestions, suggestionError == nil {
                Text("Choose a workout type, then find routes.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ForEach(suggestionRuns) { run in
                Button {
                    selectedSuggestionId = run.id
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(run.compassLabel) · \(run.distanceKmString)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(detailLine(for: run))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if selectedSuggestionId == run.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailLine(for run: SuggestedRouteRun) -> String {
        var parts: [String] = [run.ascentString]
        if !run.gradeString.isEmpty { parts.append(run.gradeString) }
        return parts.joined(separator: " · ")
    }

    private func loadRouteSuggestions() async {
        guard let c = coordinate else { return }
        isLoadingSuggestions = true
        suggestionError = nil
        defer { isLoadingSuggestions = false }
        do {
            let runs = try await RouteSuggestionService.suggestRoutes(center: c, intent: workoutIntent)
            suggestionRuns = runs
            selectedSuggestionId = runs.first?.id
        } catch is CancellationError {
            suggestionRuns = []
        } catch {
            suggestionRuns = []
            suggestionError = error.localizedDescription
        }
    }

    private var stravaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                MapDataSourcesView()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Map data sources")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(stravaCardSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            if showStravaRoutesOnMap, stravaLink.isConnected {
                HStack(spacing: 10) {
                    Button("Refresh routes") {
                        stravaLink.requestMapDataRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Text(stravaPolylines.isEmpty ? "No polylines yet — try Refresh, or check that recent activities include GPS." : "Purple lines are recent Strava activities (not navigation routes).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var stravaCardSubtitle: String {
        if stravaLink.isConnected, showStravaRoutesOnMap {
            return "Strava on — routes shown when available."
        }
        if stravaLink.isConnected {
            return "Strava signed in — turn on “Show routes” in Map data sources to draw on the map."
        }
        return "Strava, Client ID/secret, and map overlay settings."
    }

    private var overlayCaption: String {
        var parts: [String] = []
        parts.append("Apple Maps traffic colors show live congestion on the map (where available).")
        parts.append("Official state 511 remains authoritative for closures and incidents.")
        if StateTrafficOverlayFeeds.hasRegisteredFeed(forStateAbbrev: stateAbbrev) {
            if dotOverlayFeatures.isEmpty {
                parts.append("Orange markers or lines are agency data for this state when the feed returns geometry in view.")
            } else {
                parts.append("Orange markers/lines are from the registered state DOT layer (informational only).")
            }
        } else {
            parts.append("No in-app DOT geometry feed is registered for this state yet; use Open 511 below.")
        }
        if showStravaRoutesOnMap, stravaLink.isConnected, !stravaPolylines.isEmpty {
            parts.append("Purple lines are from Strava.")
        }
        if !displayedSuggestedPolylines.isEmpty {
            parts.append("Green line is a suggested out-and-back route (beta).")
        }
        return parts.joined(separator: " ")
    }

    private var displayedSuggestedPolylines: [[CLLocationCoordinate2D]] {
        guard let id = selectedSuggestionId,
              let run = suggestionRuns.first(where: { $0.id == id }) else { return [] }
        return [run.coordinates]
    }

    private var coordinateKey: String {
        guard let c = coordinate else { return "" }
        return "\(c.latitude),\(c.longitude)"
    }

    @ViewBuilder
    private var mapLayer: some View {
        if let c = coordinate {
            RouteTrafficMapView(
                region: mapRegion,
                centerPin: c,
                centerTitle: "StrideCheck area",
                dotFeatures: dotOverlayFeatures,
                stravaPolylines: stravaPolylines,
                suggestedPolylines: displayedSuggestedPolylines
            )
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
        mapRegion = MKCoordinateRegion(center: c, latitudinalMeters: 4500, longitudinalMeters: 4500)
    }
}
