import Foundation

// MARK: - Top-level output from `cyme --json --tree`

struct CymeOutput: Decodable {
    let buses: [CymeBus]
}

struct CymeBus: Decodable {
    let name: String
    let hostController: String?
    let hostControllerDevice: String?
    let usbBusNumber: Int
    let devices: [CymeDevice]?   // absent when bus has no attached devices

    enum CodingKeys: String, CodingKey {
        case name
        case hostController = "host_controller"
        case hostControllerDevice = "host_controller_device"
        case usbBusNumber = "usb_bus_number"
        case devices
    }
}

// MARK: - Device (nested in tree mode via `devices` array)

struct CymeDevice: Decodable {
    let name: String
    let vendorId: Int
    let productId: Int
    let locationId: LocationId
    let manufacturer: String?
    let bcdDevice: String?
    let bcdUsb: String?
    let deviceSpeed: String
    let deviceClass: String
    let subClass: Int
    let serialNum: String?
    let extra: DeviceExtra?
    let devices: [CymeDevice]?   // nested children (tree mode only)

    enum CodingKeys: String, CodingKey {
        case name
        case vendorId = "vendor_id"
        case productId = "product_id"
        case locationId = "location_id"
        case manufacturer
        case bcdDevice = "bcd_device"
        case bcdUsb = "bcd_usb"
        case deviceSpeed = "device_speed"
        case deviceClass = "class"
        case subClass = "sub_class"
        case serialNum = "serial_num"
        case extra
        case devices
    }
}

struct LocationId: Decodable {
    let bus: Int
    let treePositions: [Int]
    let number: Int

    enum CodingKeys: String, CodingKey {
        case bus
        case treePositions = "tree_positions"
        case number
    }
}

struct DeviceExtra: Decodable {
    let configurations: [DeviceConfiguration]?
    let hub: HubDescriptor?
    let negotiatedSpeed: String?

    enum CodingKeys: String, CodingKey {
        case configurations
        case hub
        case negotiatedSpeed = "negotiated_speed"
    }
}

struct DeviceConfiguration: Decodable {
    let maxPower: PowerInfo?
    let attributes: [String]?

    enum CodingKeys: String, CodingKey {
        case maxPower = "max_power"
        case attributes
    }
}

struct PowerInfo: Decodable {
    let value: Int
    let unit: String
}

struct HubDescriptor: Decodable {
    let numPorts: Int?

    enum CodingKeys: String, CodingKey {
        case numPorts = "num_ports"
    }
}
