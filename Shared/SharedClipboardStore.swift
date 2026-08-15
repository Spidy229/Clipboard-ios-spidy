import Foundation
import SwiftUI

enum SharedClipColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case gray

    var id: Self { self }

    var title: String {
        switch self {
        case .red: "Rojo"
        case .orange: "Naranja"
        case .yellow: "Amarillo"
        case .green: "Verde"
        case .blue: "Azul"
        case .purple: "Morado"
        case .gray: "Gris"
        }
    }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .gray: .gray
        }
    }
}

struct SharedClipboardClip: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var kindRawValue: String
    var isFavorite: Bool
    var isPinned: Bool
    var folderName: String? = nil
    var colorTagRawValue: String? = nil

    var kindSymbol: String {
        switch kindRawValue {
        case "link": "link"
        case "image": "photo"
        case "email": "envelope"
        case "phone": "phone"
        default: "text.alignleft"
        }
    }
}

enum SharedClipboardStore {
    static let appGroupID = "group.b4696920c1495422.1"
    private static let fileName = "super-portapapeles-history.json"
    private static let foldersKey = "super-portapapeles-folders"

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

    static func loadFolders() -> [String] {
        let stored = UserDefaults(suiteName: appGroupID)?.stringArray(forKey: foldersKey) ?? []
        return stored.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    @discardableResult
    static func addFolder(_ proposedName: String) -> String? {
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var folders = loadFolders()
        if let existing = folders.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        folders.append(name)
        UserDefaults(suiteName: appGroupID)?.set(folders, forKey: foldersKey)
        return name
    }

    static func removeFolder(_ name: String) {
        let folders = loadFolders().filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        UserDefaults(suiteName: appGroupID)?.set(folders, forKey: foldersKey)

        var clips = load()
        for index in clips.indices where clips[index].folderName == name {
            clips[index].folderName = nil
        }
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

