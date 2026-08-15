import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let historyKey = "keyboardTextHistory"
    private var host: UIHostingController<KeyboardView>?
    private var texts: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        texts = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        refreshClipboard()
        installKeyboardView()

        let height = view.heightAnchor.constraint(equalToConstant: 300)
        height.priority = .defaultHigh
        height.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshClipboard()
        updateView()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateView()
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

    private func makeView() -> KeyboardView {
        KeyboardView(
            texts: texts,
            hasFullAccess: hasFullAccess,
            needsGlobeKey: needsInputModeSwitchKey,
            insert: { [weak self] text in self?.textDocumentProxy.insertText(text) },
            refresh: { [weak self] in
                self?.refreshClipboard()
                self?.updateView()
            },
            delete: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            insertSpace: { [weak self] in self?.textDocumentProxy.insertText(" ") },
            insertReturn: { [weak self] in self?.textDocumentProxy.insertText("\n") },
            nextKeyboard: { [weak self] in self?.advanceToNextInputMode() }
        )
    }

    private func updateView() {
        host?.rootView = makeView()
    }

    private func refreshClipboard() {
        guard hasFullAccess,
              let value = UIPasteboard.general.string?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return }

        texts.removeAll { $0 == value }
        texts.insert(value, at: 0)
        texts = Array(texts.prefix(30))
        UserDefaults.standard.set(texts, forKey: historyKey)
    }
}

private struct KeyboardView: View {
    let texts: [String]
    let hasFullAccess: Bool
    let needsGlobeKey: Bool
    let insert: (String) -> Void
    let refresh: () -> Void
    let delete: () -> Void
    let insertSpace: () -> Void
    let insertReturn: () -> Void
    let nextKeyboard: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Portapapeles", systemImage: "clipboard")
                    .font(.headline)
                Spacer()
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 30)
                }
                .buttonStyle(.bordered)
            }

            if !hasFullAccess {
                ContentUnavailableView(
                    "Permite acceso total",
                    systemImage: "lock.open",
                    description: Text("ActÃ­valo en Ajustes para leer el portapapeles.")
                )
                .frame(maxHeight: .infinity)
            } else if texts.isEmpty {
                ContentUnavailableView(
                    "Sin textos copiados",
                    systemImage: "doc.on.clipboard"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                            Button {
                                insert(text)
                            } label: {
                                Text(text)
                                    .font(.callout)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if needsGlobeKey {
                    key("globe", action: nextKeyboard)
                }
                key("delete.left", action: delete)
                Button(action: insertSpace) {
                    Text("espacio")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                key("return", action: insertReturn)
            }
        }
        .padding(8)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func key(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 42, height: 36)
        }
        .buttonStyle(.bordered)
    }
}

