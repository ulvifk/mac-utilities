import Foundation

enum UserDefaults {
    static let standard = Foundation.UserDefaults(suiteName: CommandLine.arguments[1])!
}

let preferences = KeepAwakePreferences()

switch CommandLine.arguments[2] {
case "enable":
    precondition(!preferences.onlyWhileConnectedToPower, "The power option must default to off")
    preferences.setOnlyWhileConnectedToPower(true)
case "disable":
    precondition(preferences.onlyWhileConnectedToPower, "A new process did not load the enabled power option")
    preferences.setOnlyWhileConnectedToPower(false)
case "verify-disabled":
    precondition(!preferences.onlyWhileConnectedToPower, "A new process did not load the disabled power option")
default:
    fatalError("Unknown preference scenario")
}

precondition(UserDefaults.standard.synchronize(), "Could not save the test preferences")
