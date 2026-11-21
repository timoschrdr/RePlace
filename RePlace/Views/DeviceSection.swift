import SwiftUI

struct DeviceSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Device")
            HStack(spacing: 8) {
                deviceSymbols

                Menu {
                    Picker("Device", selection: $model.selectedDeviceID) {
                        ForEach(model.devices) { device in
                            if let symbol = device.transport.symbol {
                                Label(device.label, systemImage: symbol).tag(Optional(device.id))
                            } else {
                                Text(device.label).tag(Optional(device.id))
                            }
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .contentShape(.rect)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(model.devices.isEmpty)

                Button {
                    Task { await model.refreshDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.circle)
                .help("Reload devices")
                .accessibilityLabel("Reload devices")
            }
            .pill()
        }
    }

    /// The device symbol, with a smaller one for the connection (cable or network) next to it. A menu
    /// draws only the first image of its label, so both sit beside the menu. The connection symbol
    /// is deliberately not colored, so it does not look like a warning.
    private var deviceSymbols: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
                .foregroundStyle(.primary)
            if let transport = selectedDevice?.transport, let symbol = transport.symbol {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .help(transport.explanation ?? "")
                    .accessibilityLabel(transport.explanation ?? "")
            }
        }
    }

    private var selectedDevice: Device? {
        model.devices.first { $0.id == model.selectedDeviceID }
    }

    private var selectedLabel: String {
        selectedDevice?.label ?? String(localized: "No iPhone connected")
    }
}
