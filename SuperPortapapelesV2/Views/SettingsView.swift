import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [ClipboardItem]

    @AppStorage("requireBiometrics") private var requireBiometrics = false
    @AppStorage("skipOneTimeCodes") private var skipOneTimeCodes = true
    @AppStorage("localClipboardOnly") private var localClipboardOnly = true
    @AppStorage("maximumItems") private var maximumItems = 250
    @AppStorage("autoDeleteDays") private var autoDeleteDays = 30

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Proteger con Face ID", isOn: $requireBiometrics)
                    Toggle("No guardar códigos de un solo uso", isOn: $skipOneTimeCodes)
                    Toggle("Copiar solo en este dispositivo", isOn: $localClipboardOnly)
                } header: {
                    Text("Privacidad")
                } footer: {
                    Text("El modo local evita que lo copiado se envíe mediante Portapapeles universal.")
                }

                Section {
                    Picker("Límite", selection: $maximumItems) {
                        Text("50 elementos").tag(50)
                        Text("100 elementos").tag(100)
                        Text("250 elementos").tag(250)
                        Text("500 elementos").tag(500)
                    }

                    Picker("Borrado automático", selection: $autoDeleteDays) {
                        Text("Nunca").tag(0)
                        Text("Después de 1 día").tag(1)
                        Text("Después de 7 días").tag(7)
                        Text("Después de 30 días").tag(30)
                        Text("Después de 90 días").tag(90)
                    }
                } header: {
                    Text("Historial")
                } footer: {
                    Text("Los favoritos y los elementos fijados nunca se eliminan automáticamente.")
                }

                Section("Datos locales") {
                    LabeledContent("Elementos guardados", value: "\(items.count)")
                    Button("Borrar historial no protegido", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                Section("Acerca de") {
                    LabeledContent("Versión", value: "2.0")
                    Text("Los datos se guardan únicamente en el dispositivo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .confirmationDialog(
                "¿Borrar el historial?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Borrar textos e imágenes", role: .destructive) {
                    deleteUnprotectedItems()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se conservarán los favoritos y los elementos fijados.")
            }
        }
    }

    private func deleteUnprotectedItems() {
        for item in items where !item.isFavorite && !item.isPinned {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

