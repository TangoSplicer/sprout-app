// Kotlin bridge (simplified)
class SproutPlugin : FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "takePhoto" -> takePhoto(result)
      "scanQrCode" -> scanQrCode(result)
      "getCurrentLocation" -> getCurrentLocation(result)
      "vibrate" -> vibrate(call, result)
      "scheduleAlarm" -> scheduleAlarm(call, result)
      else -> result.notImplemented()
    }
  }
}