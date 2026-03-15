import Foundation

enum PortType {
    case magsafe
    case thunderbolt4   // USB4 / TB4, USB-C form factor
    case thunderbolt3   // USB3.2 Gen 2 + TB3, USB-C form factor
    case usbc           // USB-C, non-Thunderbolt
    case usba           // USB-A (typically USB 3.x)
    case hdmi
    case sdCard
    case headphone

    var label: String {
        switch self {
        case .magsafe:      return "MagSafe"
        case .thunderbolt4: return "TB4"
        case .thunderbolt3: return "TB3"
        case .usbc:         return "USB-C"
        case .usba:         return "USB-A"
        case .hdmi:         return "HDMI"
        case .sdCard:       return "SD"
        case .headphone:    return "3.5mm"
        }
    }

    var sfSymbol: String {
        switch self {
        case .magsafe:                  return "bolt.fill"
        case .thunderbolt4, .thunderbolt3: return "bolt.circle.fill"
        case .usbc:                     return "circle.fill"
        case .usba:                     return "rectangle.fill"
        case .hdmi:                     return "tv.fill"
        case .sdCard:                   return "memorychip.fill"
        case .headphone:                return "headphones"
        }
    }

    var maxSpeed: USBSpeed {
        switch self {
        case .thunderbolt4: return .usb4
        case .thunderbolt3: return .superSpeedPlus
        case .usbc:         return .superSpeedPlus
        case .usba:         return .superSpeedPlus
        case .magsafe, .hdmi, .sdCard, .headphone: return .unknown
        }
    }
}

struct PhysicalPort: Identifiable {
    let id: String
    let label: String
    let type: PortType
    /// Index into apciecN (0-based) for Thunderbolt ports; nil for non-TB
    let apciecIndex: Int?
}

enum MacSide {
    case left, right
}

struct SidedPort {
    let port: PhysicalPort
    let side: MacSide
}

struct MacPortLayout {
    let modelId: String
    let name: String
    let leftPorts: [PhysicalPort]
    let rightPorts: [PhysicalPort]

    var allPorts: [SidedPort] {
        leftPorts.map { SidedPort(port: $0, side: .left) } +
        rightPorts.map { SidedPort(port: $0, side: .right) }
    }

    func apciecIndex(forPort port: PhysicalPort) -> Int? {
        port.apciecIndex
    }
}

// MARK: - Known Mac Models

enum MacModelDatabase {
    static let layouts: [String: MacPortLayout] = [
        // MacBook Pro 16" M1 Pro (Late 2021)
        "MacBookPro18,1": mbp16_m1,
        // MacBook Pro 16" M1 Max (Late 2021) — user's machine
        "MacBookPro18,2": mbp16_m1,
        // MacBook Pro 14" M1 Pro (Late 2021)
        "MacBookPro18,3": mbp14_m1,
        // MacBook Pro 14" M1 Max (Late 2021)
        "MacBookPro18,4": mbp14_m1,
        // MacBook Pro 16" M2 Pro (Jan 2023)
        "MacBookPro19,1": mbp16_m2,
        // MacBook Pro 16" M2 Max (Jan 2023)
        "MacBookPro19,2": mbp16_m2,
        // MacBook Pro 14" M2 Pro (Jan 2023)
        "MacBookPro19,3": mbp14_m2,
        // MacBook Pro 14" M2 Max (Jan 2023)
        "MacBookPro19,4": mbp14_m2,
        // MacBook Pro 16" M3 Pro (Nov 2023)
        "MacBookPro20,1": mbp16_m3,
        // MacBook Pro 16" M3 Max (Nov 2023)
        "MacBookPro20,2": mbp16_m3,
        // MacBook Pro 14" M3 / Pro / Max (Nov 2023)
        "MacBookPro20,3": mbp14_m3,
        "MacBookPro20,4": mbp14_m3,
        // MacBook Air M2 (2022)
        "MacBookAir14,2": mba_m2,
        // MacBook Air M3 15" (2024)
        "MacBookAir15,2": mba_m3_15,
        // Mac mini M1 (2020)
        "Macmini9,1": macmini_m1,
        // Mac mini M2 (2023)
        "Mac14,3": macmini_m2,
        // Mac mini M2 Pro (2023)
        "Mac14,12": macmini_m2pro,
        // Mac Studio M1 Max (2022)
        "Mac13,1": macstudio_m1max,
        // Mac Studio M1 Ultra (2022)
        "Mac13,2": macstudio_m1ultra,
        // Mac Studio M2 Max (2023)
        "Mac14,13": macstudio_m2max,
        // Mac Studio M2 Ultra (2023)
        "Mac14,14": macstudio_m2ultra,
    ]

    static func layout(for modelId: String) -> MacPortLayout? {
        layouts[modelId]
    }

    // MARK: - MacBook Pro layouts

    private static let mbp16_m1 = MacPortLayout(
        modelId: "MacBookPro18,x",
        name: "MacBook Pro 16\" (M1 Pro/Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.0", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mbp14_m1 = MacPortLayout(
        modelId: "MacBookPro18,x",
        name: "MacBook Pro 14\" (M1 Pro/Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.0", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mbp16_m2 = MacPortLayout(
        modelId: "MacBookPro19,x",
        name: "MacBook Pro 16\" (M2 Pro/Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mbp14_m2 = MacPortLayout(
        modelId: "MacBookPro19,x",
        name: "MacBook Pro 14\" (M2 Pro/Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mbp16_m3 = MacPortLayout(
        modelId: "MacBookPro20,x",
        name: "MacBook Pro 16\" (M3 Pro/Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mbp14_m3 = MacPortLayout(
        modelId: "MacBookPro20,x",
        name: "MacBook Pro 14\" (M3 / Pro / Max)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
        ],
        rightPorts: [
            PhysicalPort(id: "hdmi", label: "HDMI 2.1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "sdcard", label: "SD Card", type: .sdCard, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mba_m2 = MacPortLayout(
        modelId: "MacBookAir14,2",
        name: "MacBook Air (M2, 2022)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
        ],
        rightPorts: [
            PhysicalPort(id: "usba", label: "USB-A", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let mba_m3_15 = MacPortLayout(
        modelId: "MacBookAir15,2",
        name: "MacBook Air 15\" (M3)",
        leftPorts: [
            PhysicalPort(id: "magsafe", label: "MagSafe 3", type: .magsafe, apciecIndex: nil),
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
        ],
        rightPorts: [
            PhysicalPort(id: "usba", label: "USB-A", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "audio", label: "3.5mm", type: .headphone, apciecIndex: nil),
        ]
    )

    private static let macmini_m1 = MacPortLayout(
        modelId: "Macmini9,1",
        name: "Mac mini (M1, 2020)",
        leftPorts: [],
        rightPorts: [
            PhysicalPort(id: "tb3-0", label: "TB3 #1", type: .thunderbolt3, apciecIndex: 0),
            PhysicalPort(id: "tb3-1", label: "TB3 #2", type: .thunderbolt3, apciecIndex: 1),
            PhysicalPort(id: "hdmi", label: "HDMI 2.0", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macmini_m2 = MacPortLayout(
        modelId: "Mac14,3",
        name: "Mac mini (M2, 2023)",
        leftPorts: [],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "hdmi-0", label: "HDMI #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macmini_m2pro = MacPortLayout(
        modelId: "Mac14,12",
        name: "Mac mini (M2 Pro, 2023)",
        leftPorts: [],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
            PhysicalPort(id: "hdmi-0", label: "HDMI #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macstudio_m1max = MacPortLayout(
        modelId: "Mac13,1",
        name: "Mac Studio (M1 Max, 2022)",
        leftPorts: [
            PhysicalPort(id: "usbc-f0", label: "USB-C (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "usbc-f1", label: "USB-C (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "sdcard-f", label: "SD Card", type: .sdCard, apciecIndex: nil),
        ],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
            PhysicalPort(id: "tb4-3", label: "TB4 #4", type: .thunderbolt4, apciecIndex: 3),
            PhysicalPort(id: "hdmi-0", label: "HDMI #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macstudio_m1ultra = MacPortLayout(
        modelId: "Mac13,2",
        name: "Mac Studio (M1 Ultra, 2022)",
        leftPorts: [
            PhysicalPort(id: "tb4-f0", label: "TB4 (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "tb4-f1", label: "TB4 (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "sdcard-f", label: "SD Card", type: .sdCard, apciecIndex: nil),
        ],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
            PhysicalPort(id: "tb4-3", label: "TB4 #4", type: .thunderbolt4, apciecIndex: 3),
            PhysicalPort(id: "hdmi-0", label: "HDMI #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macstudio_m2max = MacPortLayout(
        modelId: "Mac14,13",
        name: "Mac Studio (M2 Max, 2023)",
        leftPorts: [
            PhysicalPort(id: "usbc-f0", label: "USB-C (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "usbc-f1", label: "USB-C (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "sdcard-f", label: "SD Card", type: .sdCard, apciecIndex: nil),
        ],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
            PhysicalPort(id: "tb4-3", label: "TB4 #4", type: .thunderbolt4, apciecIndex: 3),
            PhysicalPort(id: "hdmi-0", label: "HDMI 2.1 #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI 2.1 #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )

    private static let macstudio_m2ultra = MacPortLayout(
        modelId: "Mac14,14",
        name: "Mac Studio (M2 Ultra, 2023)",
        leftPorts: [
            PhysicalPort(id: "tb4-f0", label: "TB4 (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "tb4-f1", label: "TB4 (F)", type: .thunderbolt4, apciecIndex: nil),
            PhysicalPort(id: "sdcard-f", label: "SD Card", type: .sdCard, apciecIndex: nil),
        ],
        rightPorts: [
            PhysicalPort(id: "tb4-0", label: "TB4 #1", type: .thunderbolt4, apciecIndex: 0),
            PhysicalPort(id: "tb4-1", label: "TB4 #2", type: .thunderbolt4, apciecIndex: 1),
            PhysicalPort(id: "tb4-2", label: "TB4 #3", type: .thunderbolt4, apciecIndex: 2),
            PhysicalPort(id: "tb4-3", label: "TB4 #4", type: .thunderbolt4, apciecIndex: 3),
            PhysicalPort(id: "hdmi-0", label: "HDMI 2.1 #1", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "hdmi-1", label: "HDMI 2.1 #2", type: .hdmi, apciecIndex: nil),
            PhysicalPort(id: "usba-0", label: "USB-A #1", type: .usba, apciecIndex: nil),
            PhysicalPort(id: "usba-1", label: "USB-A #2", type: .usba, apciecIndex: nil),
        ]
    )
}
