import SwiftUI
import MapKit

/// A bundled Natural Earth map; no network request is needed to draw country boundaries.
private enum CountryBoundaries {
    struct Shape {
        let code: String
        let overlay: MKOverlay
    }

    static let shapes: [Shape] = {
        guard let url = Bundle.main.url(forResource: "world", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let features = try? MKGeoJSONDecoder().decode(data) else { return [] }
        return features.compactMap { $0 as? MKGeoJSONFeature }.flatMap { feature -> [Shape] in
            guard let properties = feature.properties,
                  let values = (try? JSONSerialization.jsonObject(with: properties)) as? [String: Any] else { return [] }
            let primary = values["ISO_A2"] as? String ?? ""
            let code = primary.count == 2 && primary != "-99" ? primary : (values["ISO_A2_EH"] as? String ?? "")
            return feature.geometry.compactMap { geometry in
                guard let overlay = geometry as? MKOverlay else { return nil }
                return Shape(code: code, overlay: overlay)
            }
        }
    }()
}

private final class WorldMap: MKMapView {
    private var hasSetInitialRegion = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !hasSetInitialRegion, bounds.width > 0, bounds.height > 0 else { return }
        hasSetInitialRegion = true
        setVisibleMapRect(.world, edgePadding: .zero, animated: false)
    }
}

struct CountryMapView: UIViewRepresentable {
    let countries: [String]

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MKMapView {
        let map = WorldMap()
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.pointOfInterestFilter = .excludingAll
        map.mapType = .mutedStandard
        map.addOverlays(CountryBoundaries.shapes.map(\.overlay))
        return map
    }
    func updateUIView(_ map: MKMapView, context: Context) {
        let codes = Set(countries.compactMap(CountryFlags.code))
        guard codes != context.coordinator.codes else { return }
        context.coordinator.codes = codes
        for shape in CountryBoundaries.shapes {
            if let renderer = map.renderer(for: shape.overlay) as? MKOverlayPathRenderer {
                context.coordinator.style(renderer, visited: codes.contains(shape.code))
                renderer.setNeedsDisplay()
            }
        }
    }
    final class Coordinator: NSObject, MKMapViewDelegate {
        var codes = Set<String>()
        func style(_ renderer: MKOverlayPathRenderer, visited: Bool) {
            renderer.fillColor = visited ? UIColor(red: 0.10, green: 0.82, blue: 0.85, alpha: 0.72) : UIColor(red: 0.32, green: 0.39, blue: 0.43, alpha: 0.35)
            renderer.strokeColor = UIColor(white: 0.8, alpha: 0.5)
            renderer.lineWidth = 0.6
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer: MKOverlayPathRenderer
            if let polygon = overlay as? MKPolygon { renderer = MKPolygonRenderer(polygon: polygon) }
            else if let polygons = overlay as? MKMultiPolygon { renderer = MKMultiPolygonRenderer(multiPolygon: polygons) }
            else { return MKOverlayRenderer(overlay: overlay) }
            let code = CountryBoundaries.shapes.first { ($0.overlay as AnyObject) === (overlay as AnyObject) }?.code ?? ""
            style(renderer, visited: codes.contains(code))
            return renderer
        }
    }
}
