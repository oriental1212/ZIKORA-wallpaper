import SwiftUI

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.preview()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
