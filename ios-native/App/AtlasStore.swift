import Foundation
import SwiftUI

@MainActor
final class AtlasStore: ObservableObject {
    @Published var data: AtlasData?
    @Published var loading = false
    @Published var saving = false
    @Published var error: String?
    private var baseURL: URL?
    private var endpoints: [String] {
        #if DEBUG
        if let value=ProcessInfo.processInfo.environment["ATLAS_TEST_BASE"], value == "http://127.0.0.1:18780" { return [value] }
        #endif
        return ["http://192.168.32.48:7780", "http://100.94.227.14:7780"]
    }

    func load() async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        var failure = "The server could not be reached."
        for address in endpoints {
            do {
                let url = URL(string: address)!
                let bytes = try await request(base: url, path: "/api/data", body: nil, timeout: 5)
                let object = try JSONDecoder().decode([String:JSONValue].self, from: bytes)
                data = AtlasData(json: object)
                baseURL = url
                return
            } catch { failure = error.localizedDescription }
        }
        error = "Unable to connect to the travel server. \(failure)"
    }

    func fetch(_ path: String) async throws -> JSONValue {
        guard let baseURL else { throw AtlasError.message("Connect to the server first.") }
        let bytes = try await request(base: baseURL, path: path, body: nil, timeout: 15)
        return try JSONDecoder().decode(JSONValue.self, from: bytes)
    }

    func post(_ path: String, body: [String:JSONValue]) async throws -> JSONValue {
        guard let baseURL else { throw AtlasError.message("Connect to the server first.") }
        let bytes = try await request(base: baseURL, path: path, body: body, timeout: 20)
        return try JSONDecoder().decode(JSONValue.self, from: bytes)
    }

    func save(kind: String, record: [String:JSONValue], id: Int?) async throws -> Record {
        let result = try await post("/api/save", body: ["kind":.string(kind), "id":id.map { .number(Double($0)) } ?? .null, "record":.object(record)])
        guard let object = result.object else { throw AtlasError.message("The server returned an invalid response.") }
        await load()
        return Record(object)
    }

    func delete(kind: String, id: Int) async throws {
        _ = try await post("/api/delete", body: ["kind":.string(kind), "id":.number(Double(id))])
        await load()
    }

    private func request(base: URL, path: String, body: [String:JSONValue]?, timeout: TimeInterval) async throws -> Data {
        guard let url = URL(string: path, relativeTo: base) else { throw AtlasError.message("Invalid server address.") }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw AtlasError.message("Invalid server response.") }
            if !(200..<300).contains(response.statusCode) {
                let message = (try? JSONDecoder().decode([String:JSONValue].self, from: data))?["error"]?.string
                throw AtlasError.message(message ?? "The server returned HTTP \(response.statusCode).")
            }
            return data
        } catch let error as AtlasError { throw error }
        catch {
            if body != nil { throw AtlasError.message("The connection was interrupted. Check the existing records before trying again; the server may have saved the change.") }
            throw error
        }
    }
}

enum AtlasError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
}

extension Color {
    static let atlasAccent = Color(red: 0.10, green: 0.82, blue: 0.85)
}

func pounds(_ value: Double?) -> String {
    guard let value else { return "—" }
    return value.formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")))
}
func recordDates(_ record: Record) -> String {
    guard !record.start.isEmpty else { return "Undated" }
    return AtlasDates.display(record.start) + (record.end.isEmpty || record.end == record.start ? "" : " – \(AtlasDates.display(record.end))")
}
func localDateISO(_ date: Date) -> String {
    let parts=Calendar.current.dateComponents([.year,.month,.day],from:date)
    return String(format:"%04d-%02d-%02d",parts.year ?? 0,parts.month ?? 0,parts.day ?? 0)
}

func localDate(fromISO value: String) -> Date? {
    let parts=value.split(separator:"-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components=DateComponents(); components.year=parts[0]; components.month=parts[1]; components.day=parts[2]; components.hour=12
    guard let date=Calendar.current.date(from:components), localDateISO(date) == value else { return nil }
    return date
}
