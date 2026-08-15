import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var host: UIHostingController<ClipboardKeyboardView>?
    private var clips: [SharedClipboardClip] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        reload(capturingPasteboard: true)
        installKeyboardView()

        let height = view.heightAnchor.constraint(equalToConstant: 310)
        height.priority = .defaultHigh
        height.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload(capturingPasteboard: true)
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        reload(capturingPasteboard: false)
    }

    private func installKeyboardView() {
        let controller = UIHostingController(rootView: makeView())
        controller.view.backgroundColor = .clear
        addChild(controller)
        view.addSubview(controller.view)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        host = controller
    }

    private func makeView() -> ClipboardKeyboardView {
        ClipboardKeyboardView(
            clips: clips,
            hasFullAccess: hasFullAccess,
            insert: { [weak self] clip in
                self?.textDocumentProxy.insertText(clip.text)
                SharedClipboardStore.markUsed(id: clip.id)
                self?.reload(capturingPasteboard: false)
            },
            toggleFavorite: { [weak self] clip in
                SharedClipboardStore.toggleFavorite(id: clip.id)
                self?.reload(capturingPasteboard: false)
            },
            refresh: { [weak self] in self?.reload(capturingPasteboard: true) },
            paste: { [weak self] in
                guard let self,
                      self.hasFullAccess,
                      let text = UIPasteboard.general.string,
                      !text.isEmpty else { return }
                self.textDocumentProxy.insertText(text)
                SharedClipboardStore.addCopiedText(text)
                self.reload(capturingPasteboard: false)
            },
            delete: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            insertSpace: { [weak self] in self?.textDocumentProxy.insertText(" ") },
            insertReturn: { [weak self] in self?.textDocumentProxy.insertText("\n") },
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )
    }

    private func reload(capturingPasteboard: Bool) {
        if capturingPasteboard, hasFullAccess, let text = UIPasteboard.general.string {
            SharedClipboardStore.addCopiedText(text)
        }
        clips = SharedClipboardStore.load()
        host?.rootView = makeView()
    }
}

private enum KeyboardFilter: String, CaseIterable, Identifiable {
    case all = "Recientes"
    case favorites = "Favoritos"
    case pinned = "Fijados"

    var id: Self { self }
}

private enum KeyboardContentFilter: String, CaseIterable, Identifiable {
    case all
    case text
    case links
    case images

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "Todos los formatos"
        case .text: "Texto"
        case .links: "Enlaces"
        case .images: "Imágenes"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .text: "doc.text"
        case .links: "link"
        case .images: "photo"
        }
    }

    func includes(_ clip: SharedClipboardClip) -> Bool {
        switch self {
        case .all:
            true
        case .text:
            !["link", "image"].contains(clip.kindRawValue)
        case .links:
            clip.kindRawValue == "link"
        case .images:
            clip.kindRawValue == "image"
        }
    }
}

private struct ClipboardKeyboardView: View {
    let clips: [SharedClipboardClip]
    let hasFullAccess: Bool
    let insert: (SharedClipboardClip) -> Void
    let toggleFavorite: (SharedClipboardClip) -> Void
    let refresh: () -> Void
    let paste: () -> Void
    let delete: () -> Void
    let insertSpace: () -> Void
    let insertReturn: () -> Void
    let nextKeyboard: () -> Void

    @State private var filter: KeyboardFilter = .all
    @AppStorage(
        "keyboardContentFilter",
        store: UserDefaults(suiteName: SharedClipboardStore.appGroupID)
    ) private var contentFilterRawValue = KeyboardContentFilter.all.rawValue
    @AppStorage(
        "keyboardFolderFilter",
        store: UserDefaults(suiteName: SharedClipboardStore.appGroupID)
    ) private var selectedFolder = ""
    @AppStorage(
        "keyboardColorFilter",
        store: UserDefaults(suiteName: SharedClipboardStore.appGroupID)
    ) private var selectedColor = ""

    private var contentFilter: KeyboardContentFilter {
        KeyboardContentFilter(rawValue: contentFilterRawValue) ?? .all
    }

    private var visibleClips: [SharedClipboardClip] {
        let sectionClips = switch filter {
        case .all: clips
        case .favorites: clips.filter(\.isFavorite)
        case .pinned: clips.filter(\.isPinned)
        }
        return sectionClips
            .filter(contentFilter.includes)
            .filter { selectedFolder.isEmpty || $0.folderName == selectedFolder }
            .filter { selectedColor.isEmpty || $0.colorTagRawValue == selectedColor }
    }

    private var hasOrganizationFilter: Bool {
        !selectedFolder.isEmpty || !selectedColor.isEmpty
    }

    private var organizationFilterColor: Color {
        if let color = SharedClipColor(rawValue: selectedColor) { return color.color }
        return selectedFolder.isEmpty ? .primary : .cyan
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            filterPicker
            clipList
            controls
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .padding(.bottom, 6)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clipboard.fill")
                .foregroundStyle(.cyan)
            Text("Portapapeles")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                Picker("Tipo de contenido", selection: $contentFilterRawValue) {
                    ForEach(KeyboardContentFilter.allCases) { item in
                        Label(item.title, systemImage: item.symbol)
                            .tag(item.rawValue)
                    }
                }
            } label: {
                Image(systemName: contentFilter.symbol)
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
            .tint(contentFilter == .all ? .secondary : .cyan)
            .accessibilityLabel("Filtrar por tipo de contenido")
            organizationMenu
            Button(action: refresh) {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
        }
    }

    private var filterPicker: some View {
        Picker("Filtro", selection: $filter) {
            ForEach(KeyboardFilter.allCases) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var organizationMenu: some View {
        Menu {
            Menu("Carpeta") {
                Button {
                    selectedFolder = ""
                } label: {
                    Label("Todas las carpetas", systemImage: selectedFolder.isEmpty ? "checkmark" : "folder")
                }

                ForEach(SharedClipboardStore.loadFolders(), id: \.self) { folder in
                    Button {
                        selectedFolder = folder
                    } label: {
                        Label(folder, systemImage: selectedFolder == folder ? "checkmark" : "folder")
                    }
                }
            }

            Menu("Etiqueta de color") {
                Button {
                    selectedColor = ""
                } label: {
                    Label("Todos los colores", systemImage: selectedColor.isEmpty ? "checkmark" : "circle")
                }

                ForEach(SharedClipColor.allCases) { color in
                    Button {
                        selectedColor = color.rawValue
                    } label: {
                        Label(color.title, systemImage: selectedColor == color.rawValue ? "checkmark" : "circle.fill")
                    }
                }
            }

            if hasOrganizationFilter {
                Divider()
                Button("Limpiar filtros", role: .destructive) {
                    selectedFolder = ""
                    selectedColor = ""
                }
            }
        } label: {
            Image(systemName: hasOrganizationFilter ? "folder.fill" : "folder")
                .foregroundStyle(organizationFilterColor)
                .frame(width: 32, height: 28)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Filtrar por carpeta o color")
    }

    @ViewBuilder
    private var clipList: some View {
        if !hasFullAccess {
            VStack(spacing: 5) {
                Label("Activa Acceso total", systemImage: "lock.open")
                    .font(.headline)
                Text("Es necesario para compartir el historial con la app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if visibleClips.isEmpty {
            ContentUnavailableView(
                clips.isEmpty ? "Historial vacío" : "No hay elementos con estos filtros",
                systemImage: contentFilter == .all
                    ? (filter == .favorites ? "star" : "clipboard")
                    : contentFilter.symbol
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(visibleClips) { clip in
                        HStack(spacing: 8) {
                            Button {
                                insert(clip)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: clip.kindSymbol)
                                        .foregroundStyle(.cyan)
                                        .frame(width: 20)
                                    if let colorRawValue = clip.colorTagRawValue,
                                       let color = SharedClipColor(rawValue: colorRawValue) {
                                        Circle()
                                            .fill(color.color)
                                            .frame(width: 8, height: 8)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(clip.text)
                                            .font(.callout)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        HStack(spacing: 6) {
                                            Text(clip.updatedAt, style: .relative)
                                            if let folder = clip.folderName {
                                                Label(folder, systemImage: "folder.fill")
                                                    .lineLimit(1)
                                            }
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                toggleFavorite(clip)
                            } label: {
                                Image(systemName: clip.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(clip.isFavorite ? .yellow : .secondary)
                                    .frame(width: 30, height: 34)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 5) {
            keyboardButton("globe", action: nextKeyboard)
            keyboardButton("doc.on.clipboard", action: paste)
            keyboardButton("delete.left", action: delete)
            Button(action: insertSpace) {
                Text("espacio")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            keyboardButton("return", action: insertReturn)
        }
    }

    private func keyboardButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 34, height: 36)
        }
        .buttonStyle(.bordered)
    }
}

