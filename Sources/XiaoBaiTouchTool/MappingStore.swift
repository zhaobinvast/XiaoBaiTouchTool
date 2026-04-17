import Foundation
import Combine

class MappingStore: ObservableObject {
    static let shared = MappingStore()

    @Published var mappings: [GestureMapping] = []

    private var fileURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("XiaoBaiTouchTool")
            .appendingPathComponent("mappings.json")
    }

    init() {
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            mappings = try JSONDecoder().decode([GestureMapping].self, from: data)
        } catch {
            print("MappingStore load error: \(error)")
        }
    }

    func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(mappings)
            let tmp = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
        } catch {
            print("MappingStore save error: \(error)")
        }
    }

    func add(_ mapping: GestureMapping) {
        // Prevent duplicate: same gesture type can only be added once
        guard !mappings.contains(where: { $0.gesture == mapping.gesture }) else { return }
        mappings.append(mapping)
        save()
    }

    func update(_ mapping: GestureMapping) {
        guard let idx = mappings.firstIndex(where: { $0.id == mapping.id }) else { return }
        mappings[idx] = mapping
        save()
    }

    func remove(at offsets: IndexSet) {
        mappings.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        mappings.removeAll { $0.id == id }
        save()
    }
}
