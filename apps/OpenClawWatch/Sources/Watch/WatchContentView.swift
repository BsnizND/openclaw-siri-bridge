import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var store: BridgeConfigurationStore
    @StateObject private var controller = WatchVoiceController()
    @StateObject private var golfWorkout = GolfWorkoutController()
    @ObservedObject private var relay = WatchRelayController.shared
    @AppStorage("clawBridgeWalkieMode") private var walkieMode = false
    @AppStorage("clawBridgeGolfMode") private var golfMode = false
    @State private var restoredStoredGolfMode = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ModeToggleButton(
                    title: "Golf",
                    systemImage: "flag.fill",
                    isOn: golfMode || golfWorkout.isActive,
                    tint: .orange,
                    action: toggleGolfMode
                )

                ModeToggleButton(
                    title: "Speak",
                    systemImage: "speaker.wave.2.fill",
                    isOn: walkieMode,
                    tint: .green,
                    action: { walkieMode.toggle() }
                )
            }

            Button {
                Task {
                    await controller.toggleRecording(
                        configuration: store.configuration,
                        wantsVoiceReply: walkieMode,
                        sourceContext: golfMode ? .golfMode : nil
                    )
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 8) {
                        Image(systemName: controller.status.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .semibold))
                        Text(recordButtonTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 92)

                    LocationReadinessDot(readiness: controller.locationReadiness)
                        .padding(10)
                        .opacity(golfMode ? 1 : 0.45)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(controller.status.isListening ? .red : .blue)
            .disabled(controller.isBusy)
            .accessibilityLabel(controller.status.isListening ? "Stop recording" : "Start recording")

            if controller.lastResponseID != nil {
                Button {
                    Task {
                        await controller.replayLastResponse(configuration: store.configuration)
                    }
                } label: {
                    Image(systemName: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Replay Jay")
            }
        }
        .padding(.horizontal, 10)
        .onAppear {
            relay.refreshOutstandingTransfers()
            restoreGolfModeIfNeeded()
        }
        .onDisappear {
            controller.stopPlayback()
        }
        .onOpenURL { url in
            guard url.scheme == "clawbridge",
                  url.host == "record" || url.path == "/record" else {
                return
            }
            Task {
                await controller.startRecordingFromComplication()
            }
        }
    }

    private func toggleGolfMode() {
        Task {
            controller.stopPlayback()
            if golfMode || golfWorkout.isActive {
                golfWorkout.stop()
                golfMode = false
                return
            }

            controller.warmLocationForGolfMode()
            let started = await golfWorkout.start()
            golfMode = started
        }
    }

    private func restoreGolfModeIfNeeded() {
        guard golfMode, !restoredStoredGolfMode else { return }
        restoredStoredGolfMode = true
        Task {
            controller.warmLocationForGolfMode()
            let started = await golfWorkout.start()
            golfMode = started
        }
    }

    private var recordButtonTitle: String {
        if controller.status.isListening {
            return "Stop"
        }
        if controller.isBusy {
            return "Busy"
        }
        return "Record"
    }
}

private struct ModeToggleButton: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.borderedProminent)
        .tint(isOn ? tint : .gray)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct LocationReadinessDot: View {
    let readiness: WatchLocationReadiness

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.85), lineWidth: 1)
            )
            .accessibilityLabel(readiness.accessibilityLabel)
    }

    private var color: Color {
        switch readiness {
        case .ready:
            .green
        case .waiting:
            .yellow
        case .denied, .unavailable:
            .red
        case .unknown:
            .gray
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(BridgeConfigurationStore(defaults: UserDefaults(suiteName: "watch-preview")!))
}
