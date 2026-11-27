import Foundation

/// Builds Keep Awake on the real Mac: the app's own defaults, IOKit, pmset and the wall clock.
enum KeepAwakeFeatureFactory {
    static func buildFeature(setMenuBarSymbol: @escaping (String?) -> Void) -> KeepAwakeFeature {
        return KeepAwakeFeature(
            preferences: KeepAwakePreferences(defaults: .standard),
            powerManagement: SystemPowerManagement(),
            clock: SystemWallClock(),
            setMenuBarSymbol: setMenuBarSymbol
        )
    }
}
