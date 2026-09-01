import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel

  var body: some View {
    VStack(spacing: 28) {
      VStack(spacing: 10) {
        Image(systemName: stateIcon)
          .font(.system(size: 52, weight: .semibold))
          .foregroundStyle(stateColor)
          .accessibilityHidden(true)
        Text(stateTitle)
          .font(.system(size: 30, weight: .bold, design: .rounded))
        Text(stateDescription)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 390)
      }

      HStack(spacing: 18) {
        readinessItem(
          title: L10n.text("readiness.power.title"),
          value: model.helperStatus.map {
            $0.acConnected
              ? L10n.text("readiness.connected") : L10n.text("readiness.disconnected")
          } ?? L10n.text("readiness.checking"),
          status: model.helperStatus.map { $0.acConnected }
        )
        readinessItem(
          title: "ChatGPT",
          value: model.chatGPTIsRunning
            ? L10n.text("readiness.running") : L10n.text("readiness.not_running"),
          status: model.chatGPTIsRunning
        )
        readinessItem(
          title: L10n.text("readiness.safety_monitor.title"),
          value: helperReadinessValue,
          status: helperReadinessStatus
        )
      }

      Button {
        Task { await model.toggle() }
      } label: {
        Text(buttonTitle)
          .font(.title3.bold())
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(stateColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(model.mode == .starting)
      .opacity(model.mode == .starting ? 0.65 : 1)

      Text(L10n.text("footer.exit_recovery"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(36)
    .frame(width: 520, height: 470)
    .background(backgroundColor)
  }

  private func readinessItem(title: String, value: String, status: Bool?) -> some View {
    VStack(spacing: 4) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Label(
        value,
        systemImage: status.map { $0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill" }
          ?? "questionmark.circle.fill"
      )
      .font(.caption.bold())
      .foregroundStyle(status.map { $0 ? Color.green : Color.orange } ?? Color.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private var stateTitle: String {
    switch model.mode {
    case .setupRequired, .normal: L10n.text("status.title.normal")
    case .starting: L10n.text("status.title.starting")
    case .active: L10n.text("status.title.active")
    case .safetyStopped: L10n.text("status.title.safety_stopped")
    case .error: L10n.text("status.title.error")
    }
  }

  private var stateDescription: String {
    switch model.mode {
    case .setupRequired: L10n.text("status.description.setup_required")
    case .normal: L10n.text("status.description.normal")
    case .starting: L10n.text("status.description.starting")
    case .active: L10n.text("status.description.active")
    case .safetyStopped(let message), .error(let message): message
    }
  }

  private var buttonTitle: String {
    switch model.mode {
    case .active, .starting: L10n.text("button.stop")
    case .setupRequired: L10n.text("button.setup_and_start")
    case .normal, .safetyStopped, .error: L10n.text("button.start")
    }
  }

  private var stateIcon: String {
    switch model.mode {
    case .setupRequired, .normal: "leaf.circle.fill"
    case .starting: "hourglass.circle.fill"
    case .active: "bolt.circle.fill"
    case .safetyStopped: "exclamationmark.shield.fill"
    case .error: "xmark.octagon.fill"
    }
  }

  private var stateColor: Color {
    switch model.mode {
    case .setupRequired, .normal: .green
    case .starting: .orange
    case .active: .red
    case .safetyStopped: .orange
    case .error: .red
    }
  }

  private var backgroundColor: Color {
    switch model.mode {
    case .active: Color.red.opacity(0.08)
    case .safetyStopped: Color.orange.opacity(0.08)
    case .error: Color.red.opacity(0.06)
    default: Color.green.opacity(0.05)
    }
  }

  private var helperReadinessValue: String {
    guard model.helperStatus != nil else { return L10n.text("readiness.checking") }
    return model.helperIsReady
      ? L10n.text("readiness.running") : L10n.text("readiness.update_required")
  }

  private var helperReadinessStatus: Bool? {
    guard model.helperStatus != nil else { return nil }
    return model.helperIsReady
  }
}
