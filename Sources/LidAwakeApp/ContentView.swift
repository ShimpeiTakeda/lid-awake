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
          title: "電源",
          value: model.helperStatus.map { $0.acConnected ? "接続中" : "未接続" } ?? "確認中",
          status: model.helperStatus.map { $0.acConnected }
        )
        readinessItem(
          title: "ChatGPT",
          value: model.chatGPTIsRunning ? "起動中" : "停止中",
          status: model.chatGPTIsRunning
        )
        readinessItem(
          title: "安全監視",
          value: model.helperStatus == nil ? "確認中" : "稼働中",
          status: model.helperStatus.map { _ in true }
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

      Text("アプリを終了すると30秒以内に通常モードへ戻ります")
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
    case .setupRequired, .normal: "通常モード"
    case .starting: "切り替え中"
    case .active: "常時起動中"
    case .safetyStopped: "安全停止しました"
    case .error: "エラー"
    }
  }

  private var stateDescription: String {
    switch model.mode {
    case .setupRequired: "初回のみ管理者認証が必要です。蓋を閉じるとMacは通常どおりスリープします。"
    case .normal: "蓋を閉じるとMacは通常どおりスリープします。"
    case .starting: "macOSのスリープ設定を確認しています。"
    case .active: "蓋を閉じてもMacとChatGPTは動作を続けます。"
    case .safetyStopped(let message), .error(let message): message
    }
  }

  private var buttonTitle: String {
    switch model.mode {
    case .active, .starting: "通常モードに戻す"
    case .setupRequired: "初期設定して常時起動を開始"
    case .normal, .safetyStopped, .error: "常時起動を開始"
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
}
