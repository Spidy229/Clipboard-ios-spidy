import Foundation
import SwiftData

@MainActor
enum KeyboardHistorySync {
    static func synchronize(with context: ModelContext) {
        importKeyboardClips(into: context)
        publishAppHistory(from: context)
    }

    static func publishAppHistory(from context: ModelContext) {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.updatedAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor) else { return }

        let clips = items.compactMap { item -> SharedClipboardClip? in
            let value = item.text ?? item.recognizedText
            guard let value, !value.isEmpty else { return nil }
            return SharedClipboardClip(
                id: item.id,
                text: value,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt,
                kindRawValue: item.kindRawValue,
                isFavorite: item.isFavorite,
                isPinned: item.isPinned,
                folderName: item.folderName,
                colorTagRawValue: item.colorTagRawValue
            )
        }
        SharedClipboardStore.save(clips)
    }

    private static func importKeyboardClips(into context: ModelContext) {
        let descriptor = FetchDescriptor<ClipboardItem>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let existingTexts = Set(existing.compactMap(\.text))

        for clip in SharedClipboardStore.load() {
            if let item = existingByID[clip.id] {
                if clip.updatedAt > item.updatedAt {
                    item.updatedAt = clip.updatedAt
                    item.isFavorite = clip.isFavorite
                    item.isPinned = clip.isPinned
                    item.folderName = clip.folderName
                    item.colorTagRawValue = clip.colorTagRawValue
                }
                continue
            }
            guard !existingTexts.contains(clip.text) else { continue }
            let data = Data(clip.text.utf8)
            context.insert(
                ClipboardItem(
                    id: clip.id,
                    createdAt: clip.createdAt,
                    updatedAt: clip.updatedAt,
                    text: clip.text,
                    kind: ClipboardKind(rawValue: clip.kindRawValue) ?? .text,
                    isFavorite: clip.isFavorite,
                    isPinned: clip.isPinned,
                    folderName: clip.folderName,
                    colorTagRawValue: clip.colorTagRawValue,
                    contentHash: ClipboardService.hash(data)
                )
            )
        }
        try? context.save()
    }
}

