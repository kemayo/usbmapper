import SwiftUI

enum USBSpeed: Int, Comparable, CustomStringConvertible {
    case unknown = 0
    case lowSpeed = 1       // 1.5 Mb/s  USB 1.0
    case fullSpeed = 2      // 12 Mb/s   USB 1.1
    case highSpeed = 3      // 480 Mb/s  USB 2.0
    case superSpeed = 4     // 5 Gb/s    USB 3.2 Gen 1
    case superSpeedPlus = 5 // 10 Gb/s   USB 3.2 Gen 2
    case superSpeed20 = 6   // 20 Gb/s   USB 3.2 Gen 2×2
    case usb4 = 7           // 40 Gb/s   USB4 / Thunderbolt 3/4
    case thunderbolt5 = 8   // 80 Gb/s   Thunderbolt 5

    static func < (lhs: USBSpeed, rhs: USBSpeed) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var description: String { shortLabel }

    var shortLabel: String {
        switch self {
        case .unknown:        return "Unknown"
        case .lowSpeed:       return "USB 1.0"
        case .fullSpeed:      return "USB 1.1"
        case .highSpeed:      return "USB 2.0"
        case .superSpeed:     return "USB 3.2 Gen 1"
        case .superSpeedPlus: return "USB 3.2 Gen 2"
        case .superSpeed20:   return "USB 3.2 Gen 2×2"
        case .usb4:           return "USB4 / TB3/4"
        case .thunderbolt5:   return "Thunderbolt 5"
        }
    }

    var speedLabel: String {
        switch self {
        case .unknown:        return "?"
        case .lowSpeed:       return "1.5 Mb/s"
        case .fullSpeed:      return "12 Mb/s"
        case .highSpeed:      return "480 Mb/s"
        case .superSpeed:     return "5 Gb/s"
        case .superSpeedPlus: return "10 Gb/s"
        case .superSpeed20:   return "20 Gb/s"
        case .usb4:           return "40 Gb/s"
        case .thunderbolt5:   return "80 Gb/s"
        }
    }

    var isUSB3OrHigher: Bool { self >= .superSpeed }
    var isUSB2OrLower: Bool { self <= .highSpeed && self != .unknown }

    /// Standard USB bus power budget for this speed tier.
    /// USB 2.0 and below: 500 mA. USB 3.x and above (and unknown): 900 mA.
    var powerBudgetMa: Int { isUSB2OrLower ? 500 : 900 }

    /// Stroke lineWidth for topology edges — thinner for slower speeds.
    var lineWidth: CGFloat {
        switch self {
        case .unknown:        return 1.5
        case .lowSpeed:       return 1.0   // 1.5 Mb/s
        case .fullSpeed:      return 1.5   // 12 Mb/s
        case .highSpeed:      return 2.0   // 480 Mb/s
        case .superSpeed:     return 2.5   // 5 Gb/s
        case .superSpeedPlus: return 3.0   // 10 Gb/s
        case .superSpeed20:   return 3.5   // 20 Gb/s
        case .usb4:           return 4.5   // 40 Gb/s
        case .thunderbolt5:   return 6.0   // 80 Gb/s
        }
    }

    var color: Color {
        switch self {
        case .unknown:        return .gray
        case .lowSpeed:       return .red
        case .fullSpeed:      return Color.orange
        case .highSpeed:      return Color(red: 0.9, green: 0.7, blue: 0)
        case .superSpeed:     return Color(red: 0.1, green: 0.6, blue: 0.2)
        case .superSpeedPlus: return Color(red: 0.0, green: 0.75, blue: 0.3)
        case .superSpeed20:   return Color(red: 0.0, green: 0.85, blue: 0.5)
        case .usb4:           return Color.blue
        case .thunderbolt5:   return Color(red: 0.4, green: 0.2, blue: 0.9)
        }
    }

    static func parse(_ str: String) -> USBSpeed {
        let parts = str.components(separatedBy: " ")
        guard parts.count >= 2, let value = Double(parts[0]) else { return .unknown }
        let mbps: Double
        switch parts[1] {
        case "Mb/s": mbps = value
        case "Gb/s": mbps = value * 1000
        default: return .unknown
        }
        switch mbps {
        case ..<2:      return .lowSpeed
        case ..<20:     return .fullSpeed
        case ..<600:    return .highSpeed
        case ..<7000:   return .superSpeed
        case ..<15000:  return .superSpeedPlus
        case ..<25000:  return .superSpeed20
        case ..<50000:  return .usb4
        default:        return .thunderbolt5
        }
    }

    /// Minimum USB speed a device could support based on bcd_usb version string.
    /// bcd_usb declares the USB spec version, not the exact speed tier.
    /// USB 3.x devices can be Gen 1 (5), Gen 2 (10), or Gen 2×2 (20).
    /// We use >= 3.0 as an indicator that the device supports SuperSpeed at minimum.
    static func minSpeed(forBcdUsb bcdUsb: String) -> USBSpeed {
        let cleaned = bcdUsb.replacingOccurrences(of: ".", with: "")
        if cleaned.hasPrefix("4") { return .usb4 }
        if cleaned.hasPrefix("3") { return .superSpeed }
        if cleaned.hasPrefix("2") { return .highSpeed }
        if cleaned.hasPrefix("1") { return .fullSpeed }
        return .unknown
    }
}
