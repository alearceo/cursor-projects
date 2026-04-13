import CoreLocation
import MapKit
import SwiftUI
import UIKit

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
    @AppStorage("stridecheck.routeSheetExpanded") private var routeSheetExpanded = true

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let expandedH = min(geo.size.height * 0.53, 440)
                let collapsedH: CGFloat = 120
                ZStack(alignment: .bottom) {
                    mapLayer
                        .frame(width: geo.size.width, height: geo.size.height)
                        .frame(minWidth: 1, minHeight: 1)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                    routeBottomSheet(expandedHeight: expandedH, collapsedHeight: collapsedH)
                }
            }
            .background(Color.strideCanvas)
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

    private func routeBottomSheet(expandedHeight: CGFloat, collapsedHeight: CGFloat) -> some View {
        let grabberReserve: CGFloat = 56
        return VStack(spacing: 0) {
            routeSheetGrabberRow
            if routeSheetExpanded {
                ScrollView {
                    route511ExpandedContent
                        .padding(16)
                }
                .frame(maxHeight: max(120, expandedHeight - grabberReserve), alignment: .top)
            } else {
                routeSheetCollapsedStrip
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .simultaneousGesture(routeSheetDragGesture())
            }
        }
        .frame(height: routeSheetExpanded ? expandedHeight : collapsedHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
        .clipped()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: routeSheetExpanded)
    }

    private var routeSheetGrabberRow: some View {
        Button(action: toggleRouteSheet) {
            VStack(spacing: 8) {
                Capsule()
                    .fill(Color.secondary.opacity(0.38))
                    .frame(width: 40, height: 5)
                    .accessibilityHidden(true)
                HStack {
                    Text("Route & 511")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: routeSheetExpanded ? "chevron.compact.down" : "chevron.compact.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(routeSheetExpanded ? "Collapse route panel" : "Expand route panel")
        .accessibilityHint("Shows suggested routes, map data sources, and state 511 link")
        .simultaneousGesture(routeSheetDragGesture())
    }

    private var routeSheetCollapsedStrip: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                routeSheetExpanded = true
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(placeName ?? "Routes & map sources")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(routeSheetCollapsedSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var routeSheetCollapsedSubtitle: String {
        var bits: [String] = []
        if !suggestionRuns.isEmpty {
            bits.append("\(suggestionRuns.count) suggested route\(suggestionRuns.count == 1 ? "" : "s")")
        }
        bits.append("Tap to expand")
        return bits.joined(separator: " · ")
    }

    private func routeSheetDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { routeSheetHandleDragEnd($0) }
    }

    private func routeSheetHandleDragEnd(_ value: DragGesture.Value) {
        let dy = value.translation.height
        let flick = value.predictedEndTranslation.height - value.translation.height
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            if routeSheetExpanded {
                if dy > 55 || flick > 140 {
                    routeSheetExpanded = false
                }
            } else {
                if dy < -45 || flick < -120 {
                    routeSheetExpanded = true
                }
            }
        }
    }

    private func toggleRouteSheet() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            routeSheetExpanded.toggle()
        }
    }

    /// Full scrollable panel (routes, Strava, 511).
    private var route511ExpandedContent: some View {
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
            .tint(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var routeSuggestionCard: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(AppTheme.accent)
                .frame(width: 3)
                .clipShape(Capsule())
                .padding(.vertical, 14)
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
                .tint(AppTheme.accent)
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(AppTheme.accent)
                .frame(width: 3)
                .clipShape(Capsule())
                .padding(.vertical, 14)
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink {
                    MapDataSourcesView()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
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
                    Button("Refresh routes") {
                        stravaLink.requestMapDataRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    Text(stravaPolylines.isEmpty ? "No polylines yet — try Refresh, or check that recent activities include GPS." : "Purple lines are recent Strava activities (not navigation routes).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                StrideTelemetryBackground()
                ContentUnavailableView(
                    "Map needs a location",
                    systemImage: "map",
                    description: Text("Open the Conditions tab and load your area first.")
                )
                .foregroundStyle(Color.strideInk)
            }
        }
    }

    private func recenterMap() {
        guard let c = coordinate else { return }
        mapRegion = MKCoordinateRegion(center: c, latitudinalMeters: 4500, longitudinalMeters: 4500)
    }
}
