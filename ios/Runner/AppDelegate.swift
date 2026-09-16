import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenRecordingBlockerView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if let window = self.window {
      addSecureProtection(to: window)
      setupScreenRecordingObserver(for: window)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func addSecureProtection(to window: UIWindow) {
    let field = UITextField()
    field.isSecureTextEntry = true
    window.addSubview(field)
    field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.first?.addSublayer(window.layer)
  }

  private func setupScreenRecordingObserver(for window: UIWindow) {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStatusChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    checkAndHandleScreenCapture(window: window)
  }

  @objc private func screenCaptureStatusChanged() {
    if let window = self.window {
      checkAndHandleScreenCapture(window: window)
    }
  }

  private func checkAndHandleScreenCapture(window: UIWindow) {
    let isCaptured = UIScreen.main.isCaptured
    if isCaptured {
      if screenRecordingBlockerView == nil {
        let blockerView = UIView(frame: window.bounds)
        blockerView.backgroundColor = .black
        blockerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let label = UILabel()
        label.text = "Screen Recording Disabled"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        blockerView.addSubview(label)
        
        NSLayoutConstraint.activate([
          label.centerXAnchor.constraint(equalTo: blockerView.centerXAnchor),
          label.centerYAnchor.constraint(equalTo: blockerView.centerYAnchor)
        ])
        
        window.addSubview(blockerView)
        screenRecordingBlockerView = blockerView
      }
    } else {
      screenRecordingBlockerView?.removeFromSuperview()
      screenRecordingBlockerView = nil
    }
  }
}
