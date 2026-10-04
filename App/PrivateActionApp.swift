import SwiftUI
import UIKit
import PrivateActionCore

@main struct PrivateActionApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environment(environment).tint(AppStyle.mint).preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.refresh() } }
                    else if phase == .background { environment.resourcePressure() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in environment.resourcePressure() }
                .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
                    if ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical { environment.resourcePressure() }
                }
        }
    }
}
