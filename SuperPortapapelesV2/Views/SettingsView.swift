import SwiftData
import SwiftUI
import UIKit

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
                    Toggle("No guardar cÃ³digos de un solo uso", isOn: $skipOneTimeCodes)
                    Toggle("Copiar solo en este dispositivo", isOn: $localClipboardOnly)
                } header: {
                    Text("Privacidad")
                } footer: {
                    Text("El modo local evita que lo copiado se envÃ­e mediante Portapapeles universal.")
                }

                Section {
                    Picker("LÃ­mite", selection: $maximumItems) {
                        Text("50 elementos").tag(50)
                        Text("100 elementos").tag(100)
                        Text("250 elementos").tag(250)
                        Text("500 elementos").tag(500)
                    }

                    Picker("Borrado automÃ¡tico", selection: $autoDeleteDays) {
                        Text("Nunca").tag(0)
                        Text("DespuÃ©s de 1 dÃ­a").tag(1)
                        Text("DespuÃ©s de 7 dÃ­as").tag(7)
                        Text("DespuÃ©s de 30 dÃ­as").tag(30)
                        Text("DespuÃ©s de 90 dÃ­as").tag(90)
                    }
                } header: {
                    Text("Historial")
                } footer: {
                    Text("Los favoritos y los elementos fijados nunca se eliminan automÃ¡ticamente.")
                }

                Section("Datos locales") {
                    LabeledContent("Elementos guardados", value: "\(items.count)")
                    Button("Borrar historial no protegido", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Abrir ajustes para activar el teclado", systemImage: "keyboard")
                    }
                } header: {
                    Text("Teclado")
                } footer: {
                    Text("AÃ±ade Super Portapapeles en Teclados y permite Acceso total para leer los textos copiados.")
                }

                Section("Acerca de") {
                    LabeledContent("VersiÃ³n", value: "2.1")
                    Text("Los datos se guardan Ãºnicamente en el dispositivo.")
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
                "Â¿Borrar el historial?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Borrar textos e imÃ¡genes", role: .destructive) {
                    deleteUnprotectedItems()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se conservarÃ¡n los favoritos y los elementos fijados.")
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

