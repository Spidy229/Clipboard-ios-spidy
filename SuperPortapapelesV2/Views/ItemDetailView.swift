import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ClipboardItem
    @AppStorage("localClipboardOnly") private var localClipboardOnly = true
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Contenido") {
                    if let data = item.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    if let text = item.text {
                        Text(text)
                            .textSelection(.enabled)
                    }

                    if let recognizedText = item.recognizedText {
                        LabeledContent("Texto detectado") {
                            Text(recognizedText)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Organización") {
                    Toggle("Favorito", isOn: $item.isFavorite)
                    Toggle("Fijado arriba", isOn: $item.isPinned)
                    TextField("Etiquetas separadas por comas", text: $item.tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section("Información") {
                    LabeledContent("Tipo", value: item.kind.title)
                    LabeledContent("Guardado") {
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle("Detalle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        copied = ClipboardService.copy(item, localOnly: localClipboardOnly)
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel(copied ? "Copiado" : "Copiar")
                }
            }
            .onDisappear {
                item.updatedAt = .now
                try? modelContext.save()
            }
        }
    }
}

