import SwiftUI
import MapKit

extension Studio {
    var coordinate: CLLocationCoordinate2D {
        if let lat, let lon { return CLLocationCoordinate2D(latitude: lat, longitude: lon) }
        return CLLocationCoordinate2D(latitude: 29.7604, longitude: -95.3698) // Houston center
    }
}

struct MapView: View {
    @EnvironmentObject var store: Store
    @StateObject private var location = LocationManager()
    @State private var selected: Studio?
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 29.752, longitude: -95.40),
                           span: MKCoordinateSpan(latitudeDelta: 0.14, longitudeDelta: 0.14))
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(store.studios) { studio in
                    Annotation(studio.name, coordinate: studio.coordinate) {
                        Button { selected = studio } label: { pin(studio) }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea(edges: .bottom)

            // Locate-me button (top-right).
            VStack {
                HStack {
                    Spacer()
                    Button { location.requestLocation() } label: {
                        Image(systemName: "location.fill")
                            .font(.headline)
                            .padding(12)
                            .background(Palette.card(store.lightMode))
                            .foregroundColor(Palette.accent)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Palette.line(store.lightMode), lineWidth: 1))
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    }
                    .padding(.trailing, 16).padding(.top, 8)
                }
                Spacer()
            }

            if let studio = selected {
                selectedCard(studio)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selected?.id)
        .onChange(of: location.coordinate?.latitude) { _, _ in
            if let c = location.coordinate {
                withAnimation {
                    camera = .region(MKCoordinateRegion(center: c,
                        span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)))
                }
            }
        }
        .sheet(item: sheetBinding) { studio in
            NavigationStack { StudioDetailView(studio: studio) }
        }
    }

    // Tapping a pin selects it (shows card); tapping the card opens detail via this binding.
    @State private var openDetail: Studio?
    private var sheetBinding: Binding<Studio?> {
        Binding(get: { openDetail }, set: { openDetail = $0 })
    }

    private func pin(_ studio: Studio) -> some View {
        let isSel = selected?.id == studio.id
        return VStack(spacing: 2) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: isSel ? 34 : 26))
                .foregroundStyle(.white, Palette.accent)
                .shadow(radius: 3)
            Text("\(studio.credits)cr")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Palette.accent).foregroundColor(.white)
                .clipShape(Capsule())
        }
        .scaleEffect(isSel ? 1.05 : 1)
    }

    private func selectedCard(_ studio: Studio) -> some View {
        Button { openDetail = studio } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(studio.name).font(.headline).foregroundColor(Palette.text(store.lightMode))
                        Text(studio.neighborhood).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                        HStack(spacing: 4) {
                            Stars(value: studio.rating)
                            Text(String(format: "%.1f", studio.rating)).font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                            Text("· \(store.classes(for: studio.id).count) classes").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                        }
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.right.circle.fill").foregroundColor(Palette.accent)
                        Text("View").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                    }
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
