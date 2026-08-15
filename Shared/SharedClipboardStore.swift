import Foundation

struct SharedClipboardClip: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var kindRawValue: String
    var isFavorite: Bool
    var isPinned: Bool

    var kindSymbol: String {
        switch kindRawValue {
        case "link": "link"
        case "email": "envelope"
        case "phone": "phone"
        default: "text.alignleft"
        }
    }
}

enum SharedClipboardStore {
    static let appGroupID = "group.b4696920c1495422.1"
    private static let fileName = "super-portapapeles-history.json"

    static func load() -> [SharedClipboardClip] {
        guard let url = historyURL(),
              let data = try? Data(contentsOf: url),
              let clips = try? JSONDecoder().decode([SharedClipboardClip].self, from: data) else {
            return []
        }
        return sort(clips)
    }

    static func save(_ clips: [SharedClipboardClip]) {
        guard let url = historyURL(),
              let data = try? JSONEncoder().encode(sort(clips)) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func addCopiedText(_ text: String, maximumItems: Int = 250) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        var clips = load()
        if let index = clips.firstIndex(where: { $0.text == value }) {
            clips[index].updatedAt = .now
        } else {
            clips.append(
                SharedClipboardClip(
                    id: UUID(),
                    text: value,
                    createdAt: .now,
                    updatedAt: .now,
                    kindRawValue: detectKind(value),
                    isFavorite: false,
                    isPinned: false
                )
            )
        }
        save(Array(sort(clips).prefix(maximumItems)))
    }

    static func toggleFavorite(id: UUID) {
        var clips = load()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isFavorite.toggle()
        clips[index].updatedAt = .now
        save(clips)
    }

    static func markUsed(id: UUID) {
        var clips = load()
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].updatedAt = .now
        save(clips)
    }

    static func sort(_ clips: [SharedClipboardClip]) -> [SharedClipboardClip] {
        clips.sorted { first, second in
            if first.isPinned != second.isPinned { return first.isPinned }
            if first.isFavorite != second.isFavorite { return first.isFavorite }
            return first.updatedAt > second.updatedAt
        }
    }

    private static func historyURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName, isDirectory: false)
    }

    private static func detectKind(_ text: String) -> String {
        if let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return "link"
        }
        if text.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return "email"
        }
        if text.range(of: #"^\+?[0-9][0-9 ()-]{6,}$"#, options: .regularExpression) != nil {
            return "phone"
        }
        return "text"
    }
}
