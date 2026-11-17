import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillResignActive(_ scene: UIScene) {
    PrivacySnapshot.shared.resign(window: window)
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    PrivacySnapshot.shared.coverIfNeeded(window: window)
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    PrivacySnapshot.shared.activate(window: window)
  }
}

/// No screenshots are read or blurred: an opaque view covers the entire window.
/// Stay covered until Flutter confirms the lock UI/private-route exits rendered.
final class PrivacySnapshot {
  static let shared = PrivacySnapshot()
  private var channel: FlutterMethodChannel?
  private weak var window: UIWindow?
  private var cover: UIView?
  private(set) var generation = 0
  private(set) var active = false
  // Fail closed during startup until Flutter provides the current policy.
  private(set) var enabled = true

  func register(with messenger: FlutterBinaryMessenger) {
    let bridge = FlutterMethodChannel(name: "telegrive/security", binaryMessenger: messenger)
    channel = bridge
    bridge.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "setPrivateRecents":
        guard let enabled = call.arguments as? Bool else {
          result(FlutterError(code: "invalid-argument", message: nil, details: nil))
          return
        }
        self.configure(enabled: enabled)
        result(self.active ? self.generation : nil)
      case "privacyForegroundReady":
        guard let token = call.arguments as? Int else {
          result(FlutterError(code: "invalid-argument", message: nil, details: nil))
          return
        }
        self.foregroundReady(token)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func configure(enabled: Bool) {
    self.enabled = enabled
    // Turning off protection never removes an existing background cover.
    if !active { coverIfNeeded(window: window) }
  }

  func resign(window: UIWindow?) {
    generation += 1
    active = false
    self.window = window
    coverIfNeeded(window: window)
  }

  func coverIfNeeded(window: UIWindow?) {
    guard enabled, cover == nil, let window else { return }
    self.window = window
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .systemBackground
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isAccessibilityElement = false
    window.addSubview(view)
    cover = view
  }

  func activate(window: UIWindow?) {
    self.window = window
    active = true
    coverIfNeeded(window: window)
    channel?.invokeMethod("privacyActive", arguments: generation)
  }

  func foregroundReady(_ token: Int) {
    guard active, token == generation else { return }
    cover?.removeFromSuperview()
    cover = nil
  }
}
