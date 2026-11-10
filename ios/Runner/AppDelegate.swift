import Flutter
import firebase_messaging
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private var compassEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()

    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      setupCompassChannel(messenger: messenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupCompassChannel(messenger: engineBridge.binaryMessenger)
  }

  private func setupCompassChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterEventChannel(name: "com.mustafasenoglu.hac_umre_sesli_rehber/compass", binaryMessenger: messenger)
    channel.setStreamHandler(CompassStreamHandler(delegate: self))
  }

  func startUpdatingHeading(sink: @escaping FlutterEventSink) {
    self.compassEventSink = sink
    if locationManager == nil {
      locationManager = CLLocationManager()
      locationManager?.delegate = self
    }
    if CLLocationManager.headingAvailable() {
      locationManager?.startUpdatingHeading()
    } else {
      sink(FlutterError(code: "UNAVAILABLE", message: "Pusula sensörü bulunamadı", details: nil))
    }
  }

  func stopUpdatingHeading() {
    locationManager?.stopUpdatingHeading()
    compassEventSink = nil
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    compassEventSink?(heading)
  }
}

class CompassStreamHandler: NSObject, FlutterStreamHandler {
  weak var delegate: AppDelegate?
  init(delegate: AppDelegate) {
    self.delegate = delegate
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    delegate?.startUpdatingHeading(sink: events)
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate?.stopUpdatingHeading()
    return nil
  }
}
