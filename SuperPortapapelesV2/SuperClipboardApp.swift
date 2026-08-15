import SwiftData
import SwiftUI

@main
struct SuperClipboardApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: ClipboardItem.self)
        } catch {
            fatalError("No se pudo crear el almacenamiento local: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("requireBiometrics") private var requireBiometrics = false
    @StateObject private var lockController = AppLockController()

    var body: some View {
        Group {
            if requireBiometrics && lockController.isLocked {
                LockView(controller: lockController)
            } else {
                ContentView()
            }
        }
        .task {
            if requireBiometrics {
                await lockController.unlock()
            } else {
                lockController.isLocked = false
            }
        }
        .onChange(of: requireBiometrics) { _, enabled in
            lockController.isLocked = enabled
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active && requireBiometrics {
                lockController.lock()
            }
        }
    }
}

