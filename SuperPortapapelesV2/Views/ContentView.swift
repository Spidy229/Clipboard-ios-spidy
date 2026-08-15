import SwiftData
import SwiftUI
import UIKit

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "Todo"
    case text = "Texto"
    case images = "Imágenes"
    case favorites = "Favoritos"

    var id: Self { self }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \ClipboardItem.updatedAt, order: .reverse)
    private var items: [ClipboardItem]

    @AppStorage("skipOneTimeCodes") private var skipOneTimeCodes = true
    @AppStorage("localClipboardOnly") private var localClipboardOnly = true
    @AppStorage("maximumItems") private var maximumItems = 250
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 30

    @State private var filter: HistoryFilter = .all
    @State private var searchText = ""
    @State private var selectedItem: ClipboardItem?
    @State private var showingSettings = false
    @State private var toast: String?

    private var filteredItems: [ClipboardItem] {
        items.sorted { first, second in
            if first.isPinned != second.isPinned {
                return first.isPinned && !second.isPinned
            }
            return first.updatedAt > second.updatedAt
        }.filter { item in
            let matchesFilter: Bool = switch filter {
            case .all: true
            case .text: item.kind != .image
            case .images: item.kind == .image
            case .favorites: item.isFavorite
            }

            let matchesSearch = searchText.isEmpty || item.searchableText.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    ContentUnavailableView {
                        Label(
                            searchText.isEmpty ? "Tu historial está vacío" : "Sin resultados",
                            systemImage: searchText.isEmpty ? "clipboard" : "magnifyingglass"
                        )
                    } description: {
                        Text(searchText.isEmpty
                             ? "Copia un texto, una imagen o un enlace y pulsa Guardar portapapeles."
                             : "Prueba otra búsqueda o cambia el filtro.")
                    }
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            ClipboardRow(item: item)
                                .onTapGesture { selectedItem = item }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        item.isFavorite.toggle()
                                        save()
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Quitar favorito" : "Favorito",
                                            systemImage: item.isFavorite ? "star.slash" : "star"
                                        )
                                    }
                                    .tint(.yellow)

                                    Button {
                                        item.isPinned.toggle()
                                        item.updatedAt = .now
                                        save()
                                    } label: {
                                        Label(
                                            item.isPinned ? "Desfijar" : "Fijar",
                                            systemImage: item.isPinned ? "pin.slash" : "pin"
                                        )
                                    }
                                    .tint(.cyan)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(item)
                                    } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }

                                    Button {
                                        copy(item)
                                    } label: {
                                        Label("Copiar", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    Button { copy(item) } label: {
                                        Label("Copiar", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        item.isPinned.toggle()
                                        save()
                                    } label: {
                                        Label(item.isPinned ? "Desfijar" : "Fijar", systemImage: "pin")
                                    }
                                    Button(role: .destructive) { delete(item) } label: {
                                        Label("Borrar", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Super Portapapeles")
            .searchable(text: $searchText, prompt: "Buscar textos, OCR o etiquetas")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("Filtro", selection: $filter) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .safeAreaInset(edge: .bottom) {
                captureButton
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 8, y: 3)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                KeyboardHistorySync.synchronize(with: modelContext)
                cleanExpiredItems()
                trimHistoryIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                KeyboardHistorySync.synchronize(with: modelContext)
            }
        }
    }

    private var captureButton: some View {
        Button(action: captureClipboard) {
            Label("Guardar portapapeles", systemImage: "clipboard.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    private func captureClipboard() {
        switch ClipboardService.readCurrent() {
        case .empty:
            showToast("El portapapeles está vacío")
        case .unsupported:
            showToast("Este tipo de contenido aún no es compatible")
        case .content(let draft):
            if let text = draft.text,
               skipOneTimeCodes,
               ClipboardService.isLikelyOneTimeCode(text) {
                showToast("Código temporal omitido por privacidad")
                return
            }

            if let existing = items.first(where: { $0.contentHash == draft.contentHash }) {
                existing.updatedAt = .now
                save()
                showToast("Ya estaba guardado; se movió arriba")
                return
            }

            let item = ClipboardItem(
                text: draft.text,
                imageData: draft.imageData,
                kind: draft.kind,
                contentHash: draft.contentHash
            )
            modelContext.insert(item)
            save()
            trimHistoryIfNeeded()
            showToast("Guardado de forma privada")

            if let imageData = draft.imageData {
                Task {
                    item.recognizedText = await OCRService.recognizeText(in: imageData)
                    save()
                }
            }
        }
    }

    private func copy(_ item: ClipboardItem) {
        if ClipboardService.copy(item, localOnly: localClipboardOnly) {
            item.updatedAt = .now
            save()
            showToast("Copiado")
        }
    }

    private func delete(_ item: ClipboardItem) {
        modelContext.delete(item)
        save()
        showToast("Eliminado")
    }

    private func cleanExpiredItems() {
        guard autoDeleteDays > 0,
              let threshold = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: .now) else {
            return
        }

        for item in items where item.updatedAt < threshold && !item.isFavorite && !item.isPinned {
            modelContext.delete(item)
        }
        save()
    }

    private func trimHistoryIfNeeded() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.updatedAt, order: .forward)]
        )
        guard let storedItems = try? modelContext.fetch(descriptor),
              storedItems.count > maximumItems else { return }

        let removable = storedItems
            .filter { !$0.isPinned && !$0.isFavorite }

        for item in removable.prefix(max(0, storedItems.count - maximumItems)) {
            modelContext.delete(item)
        }
        save()
    }

    private func save() {
        try? modelContext.save()
        KeyboardHistorySync.publishAppHistory(from: modelContext)
    }

    private func showToast(_ message: String) {
        withAnimation(.snappy) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut) {
                if toast == message { toast = nil }
            }
        }
    }
}

