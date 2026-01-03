import Flutter
import UIKit
import LocalAuthentication

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Security: Initialize biometric authentication
        setupBiometricAuth()
        
        // Security: Setup method channel
        let controller = window?.rootViewController as! FlutterViewController
        let securityChannel = FlutterMethodChannel(
            name: "com.sproutapp.sprout/security",
            binaryMessenger: controller.binaryMessenger
        )
        
        securityChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "checkBiometricAvailability":
                self.checkBiometricAvailability(result: result)
            case "authenticate":
                self.authenticateUser(result: result)
            case "generateSecureKey":
                if let alias = call.arguments as? String {
                    self.generateSecureKey(alias: alias, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Alias required", details: nil))
                }
            case "encryptData":
                if let args = call.arguments as? [String: Any],
                   let alias = args["alias"] as? String,
                   let data = args["data"] as? FlutterStandardTypedData {
                    self.encryptData(alias: alias, data: data.data, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Alias and data required", details: nil))
                }
            case "decryptData":
                if let args = call.arguments as? [String: Any],
                   let alias = args["alias"] as? String,
                   let data = args["data"] as? FlutterStandardTypedData {
                    self.decryptData(alias: alias, data: data.data, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENT", message: "Alias and data required", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // Security: Check biometric availability
    private func checkBiometricAvailability(result: FlutterResult) {
        let context = LAContext()
        var error: NSError?
        
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        
        if canEvaluate {
            let biometryType: String
            switch context.biometryType {
            case .faceID:
                biometryType = "face_id"
            case .touchID:
                biometryType = "touch_id"
            default:
                biometryType = "unknown"
            }
            
            result([
                "status": "available",
                "hasHardware": true,
                "type": biometryType
            ])
        } else {
            result([
                "status": "not_available",
                "hasHardware": false,
                "error": error?.localizedDescription
            ])
        }
    }
    
    // Security: Authenticate user with biometrics
    private func authenticateUser(result: FlutterResult) {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access Sprout"
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(["success": true])
                    } else {
                        result(FlutterError(
                            code: "AUTH_FAILED",
                            message: error?.localizedDescription,
                            details: nil
                        ))
                    }
                }
            }
        } else {
            result(FlutterError(
                code: "BIOMETRIC_NOT_AVAILABLE",
                message: "Biometric authentication not available",
                details: nil
            ))
        }
    }
    
    // Security: Generate secure key in Keychain
    private func generateSecureKey(alias: String, result: FlutterResult) {
        // Security: Use Keychain for secure storage
        let keyData = "secure_key_\(UUID().uuidString)".data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess || status == errSecDuplicateItem {
            result(nil)
        } else {
            result(FlutterError(
                code: "KEYGEN_FAILED",
                message: "Failed to generate key",
                details: status
            ))
        }
    }
    
    // Security: Encrypt data using Keychain
    private func encryptData(alias: String, data: Data, result: FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let keyData = item as? Data {
            // Security: Simple XOR encryption (use proper encryption in production)
            var encrypted = Data()
            for (index, byte) in data.enumerated() {
                encrypted.append(byte ^ keyData[index % keyData.count])
            }
            result(FlutterStandardTypedData(bytes: encrypted))
        } else {
            result(FlutterError(
                code: "ENCRYPTION_FAILED",
                message: "Failed to retrieve key",
                details: status
            ))
        }
    }
    
    // Security: Decrypt data using Keychain
    private func decryptData(alias: String, data: Data, result: FlutterResult) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: alias,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let keyData = item as? Data {
            // Security: Simple XOR decryption (use proper decryption in production)
            var decrypted = Data()
            for (index, byte) in data.enumerated() {
                decrypted.append(byte ^ keyData[index % keyData.count])
            }
            result(FlutterStandardTypedData(bytes: decrypted))
        } else {
            result(FlutterError(
                code: "DECRYPTION_FAILED",
                message: "Failed to retrieve key",
                details: status
            ))
        }
    }
    
    // Security: Prevent screen capture
    override func applicationDidEnterBackground(_ application: UIApplication) {
        // Security: Hide sensitive content when app goes to background
        window?.isHidden = true
    }
    
    override func applicationWillEnterForeground(_ application: UIApplication) {
        // Security: Show content when app returns to foreground
        window?.isHidden = false
    }
    
    private func setupBiometricAuth() {
        // Security: Initialize biometric context
        let context = LAContext()
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
    }
}