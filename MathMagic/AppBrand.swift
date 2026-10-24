import Foundation

enum AppBrand {
    #if UNICORN_APP
    static let appTitle = "MathMagic"
    static let defaultVehicle: VehicleType = .unicorn
    static let availableVehicles: [VehicleType] = [.unicorn]
    #else
    static let appTitle = "MathPilot"
    static let defaultVehicle: VehicleType = .jet
    static let availableVehicles: [VehicleType] = [.jet, .tank]
    #endif
}
