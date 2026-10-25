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
                            Text(device.label).tag(Optional(device.id))
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

                Button {
                    Task { await model.refreshDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.circle)
                .help("Reload devices")
            }
            .pill()
        }
    }

    private var selectedLabel: String {
        model.devices.first { $0.id == model.selectedDeviceID }?.label
            ?? String(localized: "No iPhone connected")
    }
}
