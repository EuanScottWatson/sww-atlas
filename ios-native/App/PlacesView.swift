import SwiftUI
import MapKit

private final class PlacePin: NSObject, MKAnnotation, Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let country: String
    var trips: [Record]
    init(id:String,name:String,country:String,latitude:Double,longitude:Double,trips:[Record]) {
        self.id=id; self.title=name; self.country=country; self.coordinate=CLLocationCoordinate2D(latitude:latitude,longitude:longitude); self.trips=trips
    }
}
private struct NativeMap: UIViewRepresentable {
    let pins:[PlacePin]
    let selected:(PlacePin)->Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context:Context) -> MKMapView {
        let map=MKMapView(); map.delegate=context.coordinator
        map.setRegion(MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:40,longitude:0),span:MKCoordinateSpan(latitudeDelta:110,longitudeDelta:110)),animated:false)
        map.register(MKMarkerAnnotationView.self,forAnnotationViewWithReuseIdentifier:"place")
        return map
    }
    func updateUIView(_ map:MKMapView,context:Context) {
        context.coordinator.parent=self
        let encoder=JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let signature=pins.map { pin in
            let details=pin.trips.compactMap { try? encoder.encode($0.fields) }.map { $0.base64EncodedString() }.sorted().joined(separator:",")
            return "\(pin.id)|\(pin.title ?? "")|\(pin.country)|\(details)"
        }.sorted().joined(separator:"|")
        guard signature != context.coordinator.signature else { return }
        context.coordinator.signature=signature
        map.removeAnnotations(map.annotations)
        map.addAnnotations(pins)
        if pins.count == 1, let pin=pins.first { map.setRegion(MKCoordinateRegion(center:pin.coordinate,span:MKCoordinateSpan(latitudeDelta:3,longitudeDelta:3)),animated:true) }
        else if pins.count > 1 { map.showAnnotations(pins,animated:true) }
    }
    final class Coordinator:NSObject,MKMapViewDelegate {
        var parent:NativeMap; var signature=""
        init(_ parent:NativeMap) { self.parent=parent }
        func mapView(_ mapView:MKMapView,viewFor annotation:MKAnnotation) -> MKAnnotationView? {
            guard annotation is PlacePin else { return nil }
            let view=mapView.dequeueReusableAnnotationView(withIdentifier:"place",for:annotation) as! MKMarkerAnnotationView
            view.clusteringIdentifier="atlas-place"; view.markerTintColor=UIColor(Color.atlasAccent); view.canShowCallout=false
            return view
        }
        func mapView(_ mapView:MKMapView,didSelect view:MKAnnotationView) {
            if let cluster=view.annotation as? MKClusterAnnotation { mapView.showAnnotations(cluster.memberAnnotations,animated:true) }
            else if let pin=view.annotation as? PlacePin { parent.selected(pin) }
            if let annotation=view.annotation { mapView.deselectAnnotation(annotation,animated:false) }
        }
    }
}
struct PlacesView: View {
    let data:AtlasData
    @State private var mode="Visited"
    @State private var mapStyle="Countries"
    @State private var country="All countries"
    @State private var query=""
    @State private var selected:PlacePin?
    private var trips:[Record] {
        let today=localDateISO(Date())
        return data.trips.filter { !$0.start.isEmpty && (mode == "All" || (mode == "Visited" ? $0.start <= today : $0.start > today)) }
    }
    private var countries:[String] { Array(Set(trips.flatMap { data.countries(for:$0) })).sorted() }
    private var pins:[PlacePin] {
        var groups:[String:PlacePin]=[:]
        for trip in trips {
            let countries=data.countries(for:trip)
            if country != "All countries" && !countries.contains(country) { continue }
            let place=data.place(for:trip)
            let pinValues=place["pins"]?.array?.compactMap(\.object) ?? [["name":.string(place["label"]?.string ?? trip.name),"lat":place["lat"] ?? .null,"lon":place["lon"] ?? .null]]
            for pin in pinValues {
                guard let lat=pin["lat"]?.number, let lon=pin["lon"]?.number, abs(lat)<=90, abs(lon)<=180 else { continue }
                let name=pin["name"]?.string ?? trip.name, key=String(format:"%.4f,%.4f",lat,lon)
                if let existing=groups[key] { existing.trips.append(trip) }
                else { groups[key]=PlacePin(id:key,name:name,country:countries.joined(separator:", "),latitude:lat,longitude:lon,trips:[trip]) }
            }
        }
        return groups.values.filter { query.isEmpty || "\($0.title ?? "") \($0.country)".localizedCaseInsensitiveContains(query) }.sorted { ($0.title ?? "") < ($1.title ?? "") }
    }
    private var unmapped:[Record] {
        AtlasCalculations.uniqueVisits(trips.filter { trip in
            if country != "All countries" && !data.countries(for:trip).contains(country) { return false }
            let place=data.place(for:trip)
            let values=place["pins"]?.array?.compactMap(\.object) ?? [["lat":place["lat"] ?? .null,"lon":place["lon"] ?? .null]]
            let mapped=values.contains { pin in guard let lat=pin["lat"]?.number, let lon=pin["lon"]?.number else { return false }; return abs(lat)<=90 && abs(lon)<=180 }
            return !mapped && (query.isEmpty || "\(trip.name) \(data.countries(for:trip).joined(separator:" "))".localizedCaseInsensitiveContains(query))
        })
    }
    private func count(_ country:String) -> Int {
        let rows=AtlasCalculations.uniqueVisits(trips.filter { data.countries(for:$0).contains(country) })
        return Set(rows.map { $0.text("group").isEmpty ? "trip:\($0.id)" : "journey:\($0.text("group"))" }).count
    }
    var body:some View {
        List {
            Section {
                Picker("Places",selection:$mode) { Text("Visited").tag("Visited"); Text("Upcoming").tag("Upcoming"); Text("All").tag("All") }.pickerStyle(.segmented).onChange(of:mode) { _ in country="All countries" }
                Menu { Picker("Country",selection:$country) { Text("All countries").tag("All countries"); ForEach(countries,id:\.self) { Text("\(CountryFlags.flag($0)) \($0)").tag($0) } } } label: { Label(country,systemImage:"globe.europe.africa") }
                Picker("Map view",selection:$mapStyle) { Text("Countries").tag("Countries"); Text("Places").tag("Places") }.pickerStyle(.segmented)
                NavigationLink { CountryDirectoryView(mode:mode,initialData:data) } label: { Label("Explore \(countries.count) \(countries.count == 1 ? "country" : "countries")",systemImage:"flag") }.accessibilityIdentifier("country-directory")
                if mapStyle == "Countries" {
                    CountryMapView(countries:countries).frame(height:350).listRowInsets(EdgeInsets()).accessibilityLabel("World map showing recorded countries")
                    Text("Highlighted countries are based on your trips. Zoom and pan to explore. Some small islands may not appear at this map scale.").font(.footnote).foregroundStyle(.secondary)
                } else {
                    NativeMap(pins:pins) { selected=$0 }.frame(height:350).listRowInsets(EdgeInsets())
                    Text("Tap a pin for visit history. Locations are approximate.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !unmapped.isEmpty { Section("Trips without map pins") { ForEach(unmapped) { trip in NavigationLink { RecordDetailView(kind:"trips",id:trip.id) } label: { TripRow(trip:trip,data:data) } } } }
            Section("Countries · \(countries.count)") { ForEach(countries,id:\.self) { item in NavigationLink { CountryDetailView(country:item,mode:mode,initialData:data) } label: { HStack { Text(CountryFlags.flag(item)); Text(item); Spacer(); Text("\(count(item)) trips").foregroundStyle(.secondary) } } } }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle("Map")
        .modifier(KeyboardDismissToolbar())
        .onSubmit(of:.search) { dismissAtlasKeyboard() }
        .searchable(text:$query,prompt:"Search recorded places")
        .sheet(item:$selected) { pin in NavigationStack { PlaceDetailView(pin:pin,data:data) } }
    }
}
private struct PlaceDetailView:View {
    @EnvironmentObject private var store:AtlasStore
    @Environment(\.dismiss) private var dismiss
    let pin:PlacePin; let data:AtlasData
    @State private var overview:[String:JSONValue]?
    @State private var unavailable=false
    var body:some View {
        List {
            Section(pin.country) {
                if let extract=overview?["extract"]?.string { Text(extract) }
                else if unavailable { Text("Place overview unavailable.").foregroundStyle(.secondary) }
                else { ProgressView("Loading place overview…") }
                if let text=overview?["url"]?.string, let url=URL(string:text) { Link("Open Wikipedia",destination:url) }
            }
            Section("Your visits") { ForEach(AtlasCalculations.uniqueVisits(pin.trips)) { trip in NavigationLink { RecordDetailView(kind:"trips",id:trip.id) } label: { TripRow(trip:trip,data:data) } } }
        }
        .scrollContentBackground(.hidden)
        .background(Color.atlasBackground.ignoresSafeArea())
        .navigationTitle(pin.title ?? "Place").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Done") { dismiss() } } }
        .task {
            var components=URLComponents(); components.path="/api/place"; components.queryItems=[URLQueryItem(name:"name",value:pin.title),URLQueryItem(name:"country",value:pin.country),URLQueryItem(name:"lat",value:String(pin.coordinate.latitude)),URLQueryItem(name:"lon",value:String(pin.coordinate.longitude))]
            do { overview=try await store.fetch(components.string ?? "").object; unavailable=overview?["available"]?.bool == false } catch { unavailable=true }
        }
    }
}
