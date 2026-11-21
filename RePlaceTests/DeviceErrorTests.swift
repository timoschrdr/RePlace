import Testing
@testable import RePlace

@MainActor
struct DeviceErrorTests {
    @Test func recognisesTheCommonCauses() {
        #expect(DeviceError.message(for: "Developer Mode is disabled on the device").contains("Developer Mode"))
        #expect(DeviceError.message(for: "The device is locked.").contains("locked"))
        #expect(DeviceError.message(for: "A connection to a remote process could not be established. target = remoteService").contains("connection"))
        #expect(DeviceError.message(for: "The operation timed out").contains("respond"))
    }

    @Test func unknownErrorsShowTheLastLine() {
        let message = DeviceError.message(for: "first line\n  something odd happened  \n\n")
        #expect(message.contains("something odd happened"))
        #expect(!message.contains("first line"))
    }
}

@MainActor
struct DeviceTransportTests {
    @Test func mapsTheValuesOfDevicectl() {
        #expect(Device.Transport(devicectlValue: "wired") == .wired)
        #expect(Device.Transport(devicectlValue: "localNetwork") == .network)
        #expect(Device.Transport(devicectlValue: nil) == .unknown)
        #expect(Device.Transport(devicectlValue: "somethingNew") == .unknown)
    }

    @Test func eachKnownTransportHasASymbolAndAnExplanation() {
        #expect(Device.Transport.wired.symbol == "cable.connector")
        #expect(Device.Transport.network.symbol == "wifi")
        #expect(Device.Transport.unknown.symbol == nil && Device.Transport.unknown.explanation == nil)
        #expect(Device.Transport.wired.explanation != nil && Device.Transport.network.explanation != nil)
    }
}
