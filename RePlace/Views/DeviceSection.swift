import SwiftUI

struct DeviceSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Device")
            HStack(spacing: 8) {
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
                        Image(systemName: "iphone")
                            .foregroundStyle(.secondary)
                        Text(selectedLabel)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(model.devices.isEmpty)

                if let transport = selectedDevice?.transport, let symbol = transport.symbol {
                    Image(systemName: symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brand)
                        .help(transport.explanation ?? "")
                        .accessibilityLabel(transport.explanation ?? "")
                }

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

    private var selectedDevice: Device? {
        model.devices.first { $0.id == model.selectedDeviceID }
    }

    private var selectedLabel: String {
        selectedDevice?.label ?? String(localized: "No iPhone connected")
    }
}
