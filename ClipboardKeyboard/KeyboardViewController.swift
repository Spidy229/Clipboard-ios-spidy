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

private struct ClipboardKeyboardView: View {
    let clips: [SharedClipboardClip]
    let hasFullAccess: Bool
    let insert: (SharedClipboardClip) -> Void
    let toggleFavorite: (SharedClipboardClip) -> Void
    let refresh: () -> Void
    let delete: () -> Void
    let insertSpace: () -> Void
    let insertReturn: () -> Void
    let nextKeyboard: () -> Void

    @State private var filter: KeyboardFilter = .all

    private var visibleClips: [SharedClipboardClip] {
        switch filter {
        case .all: clips
        case .favorites: clips.filter(\.isFavorite)
        case .pinned: clips.filter(\.isPinned)
        }
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
            Text("Super Portapapeles")
                .font(.headline)
            Text("\(clips.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
            Spacer()
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
                filter == .all ? "Historial vacío" : "No hay \(filter.rawValue.lowercased())",
                systemImage: filter == .favorites ? "star" : "clipboard"
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
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(clip.text)
                                            .font(.callout)
                                            .lineLimit(2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(clip.updatedAt, style: .relative)
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
        HStack(spacing: 7) {
            keyboardButton("globe", action: nextKeyboard)
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
                .frame(width: 42, height: 36)
        }
        .buttonStyle(.bordered)
    }
}
