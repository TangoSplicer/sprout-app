package com.sproutapp.sprout

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.Executor
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.sproutapp.sprout/security"
    private val NATIVE_CHANNEL = "sprout/native"
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private lateinit var promptInfo: BiometricPrompt.PromptInfo
    private var nativeChannel: MethodChannel? = null
    private var pendingIncomingPackage: String? = null
    private var pendingLaunchProject: String? = null
    private var pendingPhotoResult: MethodChannel.Result? = null
    private var pendingPhotoFile: File? = null

    // Security: KeyStore for cryptographic operations
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Security: Setup biometric authentication
        setupBiometricAuth()
        
        // Security: Setup method channel for secure operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkBiometricAvailability" -> {
                    result.success(checkBiometricAvailability())
                }
                "authenticate" -> {
                    authenticateUser(result)
                }
                "generateSecureKey" -> {
                    val alias = call.argument<String>("alias")
                    if (alias != null) {
                        generateSecureKey(alias)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias required", null)
                    }
                }
                "encryptData" -> {
                    val alias = call.argument<String>("alias")
                    val data = call.argument<ByteArray>("data")
                    if (alias != null && data != null) {
                        try {
                            val encrypted = encryptData(alias, data)
                            result.success(encrypted)
                        } catch (e: Exception) {
                            result.error("ENCRYPTION_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias and data required", null)
                    }
                }
                "decryptData" -> {
                    val alias = call.argument<String>("alias")
                    val data = call.argument<ByteArray>("data")
                    if (alias != null && data != null) {
                        try {
                            val decrypted = decryptData(alias, data)
                            result.success(decrypted)
                        } catch (e: Exception) {
                            result.error("DECRYPTION_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Alias and data required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
        nativeChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "shareAppPackage" -> {
                    val packagePath = call.argument<String>("path")
                    if (packagePath.isNullOrBlank()) {
                        result.error("INVALID_ARGUMENT", "A package path is required", null)
                    } else {
                        try {
                            shareAppPackage(packagePath)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("SHARE_FAILED", error.message, null)
                        }
                    }
                }
                "consumeIncomingAppPackage" -> {
                    val packagePath = pendingIncomingPackage
                    pendingIncomingPackage = null
                    result.success(packagePath)
                }
                "consumeLaunchProject" -> {
                    val projectName = pendingLaunchProject
                    pendingLaunchProject = null
                    result.success(projectName)
                }
                "requestAppShortcut" -> {
                    val projectName = call.argument<String>("projectName")?.trim()
                    if (projectName.isNullOrEmpty() || projectName.length > 80) {
                        result.error("INVALID_ARGUMENT", "A valid project name is required", null)
                    } else {
                        result.success(requestAppShortcut(projectName))
                    }
                }
                "scheduleAlarm" -> {
                    val message = call.argument<String>("message")?.trim()
                    val timestamp = call.argument<Number>("timestamp")?.toLong()
                    if (message.isNullOrEmpty() || message.length > 500 || timestamp == null) {
                        result.error("INVALID_ARGUMENT", "A reminder message and timestamp are required", null)
                    } else if (timestamp <= System.currentTimeMillis()) {
                        result.error("INVALID_ARGUMENT", "Reminder time must be in the future", null)
                    } else {
                        try {
                            scheduleReminder(message, timestamp)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("SCHEDULE_FAILED", error.message, null)
                        }
                    }
                }
                "notifyUser" -> {
                    val message = call.argument<String>("message")?.trim()
                    if (!message.isNullOrEmpty() && message.length <= 500) {
                        scheduleReminder(message, System.currentTimeMillis() + 500)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Valid message required", null)
                    }
                }
                "takePhoto" -> startPhotoCapture(result)
                "scanQrCode" -> startBarcodeScan(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startPhotoCapture(result: MethodChannel.Result) {
        if (pendingPhotoResult != null) {
            result.error("BUSY", "A photo capture is already in progress", null)
            return
        }

        val photoFile = File(cacheDir, "sprout_photo_${System.currentTimeMillis()}.jpg")
        val photoUri = FileProvider.getUriForFile(
            this,
            "$packageName.sproutfiles",
            photoFile,
        )
        val captureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        }

        if (captureIntent.resolveActivity(packageManager) == null) {
            result.error("UNAVAILABLE", "No camera app is available on this device", null)
            return
        }

        pendingPhotoResult = result
        pendingPhotoFile = photoFile
        try {
            startActivityForResult(captureIntent, REQUEST_TAKE_PHOTO)
        } catch (error: Exception) {
            pendingPhotoResult = null
            pendingPhotoFile = null
            photoFile.delete()
            result.error("CAMERA_FAILED", error.message, null)
        }
    }

    private fun startBarcodeScan(result: MethodChannel.Result) {
        val scanner = com.google.mlkit.vision.codescanner.GmsBarcodeScanning.getClient(this)
        scanner.startScan()
            .addOnSuccessListener { barcode -> result.success(barcode.rawValue) }
            .addOnCanceledListener { result.success(null) }
            .addOnFailureListener { error ->
                result.error("SCAN_FAILED", error.message, null)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_TAKE_PHOTO) return

        val callback = pendingPhotoResult ?: return
        val photoFile = pendingPhotoFile
        pendingPhotoResult = null
        pendingPhotoFile = null

        if (resultCode == Activity.RESULT_OK && photoFile?.exists() == true && photoFile.length() > 0) {
            callback.success(photoFile.absolutePath)
        } else {
            photoFile?.delete()
            callback.success(null)
        }
    }

    private fun captureLaunchIntent(launchIntent: Intent?) {
        if (launchIntent == null) return
        val shortcutProject = launchIntent.getStringExtra(EXTRA_PROJECT_NAME)?.trim()
        if (!shortcutProject.isNullOrEmpty() && shortcutProject.length <= 80) {
            pendingLaunchProject = shortcutProject
            nativeChannel?.invokeMethod("proxyLaunchRequested", shortcutProject)
        }

        val incomingUri = when (launchIntent.action) {
            Intent.ACTION_SEND -> launchIntent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            Intent.ACTION_VIEW -> launchIntent.data
            else -> null
        }
        if (incomingUri != null) {
            try {
                pendingIncomingPackage = copyIncomingPackage(incomingUri)
                nativeChannel?.invokeMethod("incomingAppPackage", pendingIncomingPackage)
            } catch (_: Exception) {
                // Dart validates the archive. Invalid or oversized external content is ignored.
            }
        }
    }

    private fun copyIncomingPackage(uri: Uri): String {
        val destination = File(cacheDir, "incoming_${System.currentTimeMillis()}.sproutapp")
        var totalBytes = 0
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) throw IllegalArgumentException("Unable to read the shared package")
            FileOutputStream(destination).use { output ->
                val buffer = ByteArray(8192)
                while (true) {
                    val count = input.read(buffer)
                    if (count == -1) break
                    totalBytes += count
                    if (totalBytes > MAX_PACKAGE_BYTES) {
                        destination.delete()
                        throw IllegalArgumentException("Shared package is too large")
                    }
                    output.write(buffer, 0, count)
                }
            }
        }
        if (totalBytes == 0) {
            destination.delete()
            throw IllegalArgumentException("Shared package is empty")
        }
        return destination.absolutePath
    }

    private fun shareAppPackage(packagePath: String) {
        val packageFile = File(packagePath)
        if (!packageFile.isFile || packageFile.length() !in 1..MAX_PACKAGE_BYTES ||
            !packageFile.name.endsWith(".sproutapp", ignoreCase = true)) {
            throw IllegalArgumentException("The selected app package is unavailable")
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.sproutfiles", packageFile)
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/vnd.sprout.app+gzip"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newRawUri("Sprout app package", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(shareIntent, "Share Sprout app"))
    }

    private fun requestAppShortcut(projectName: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(ShortcutManager::class.java) ?: return false
        if (!manager.isRequestPinShortcutSupported) return false
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(projectName.toByteArray(Charsets.UTF_8))
            .joinToString("") { byte -> "%02x".format(byte) }
            .take(24)
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra(EXTRA_PROJECT_NAME, projectName)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val shortcut = ShortcutInfo.Builder(this, "sprout_$digest")
            .setShortLabel(projectName.take(25))
            .setLongLabel("Open $projectName in Sprout")
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(launchIntent)
            .build()
        return manager.requestPinShortcut(shortcut, null)
    }

    private fun scheduleReminder(message: String, timestamp: Long) {
        val notificationId = (timestamp xor message.hashCode().toLong()).toInt()
        val intent = Intent(this, ReminderReceiver::class.java).apply {
            putExtra(ReminderReceiver.EXTRA_MESSAGE, message)
            putExtra(ReminderReceiver.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
    }

    // Security: Check if biometric authentication is available
    private fun checkBiometricAvailability(): Map<String, Any> {
        val biometricManager = BiometricManager.from(this)
        val authStatus = biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG)
        val canAuthenticate = when (authStatus) {
            BiometricManager.BIOMETRIC_SUCCESS -> "available"
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> "no_hardware"
            BiometricManager.BIOMETRIC_ERROR_HW_UNAVAILABLE -> "unavailable"
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> "not_enrolled"
            else -> "unknown"
        }
        
        return mapOf(
            "status" to canAuthenticate,
            "hasHardware" to (authStatus == BiometricManager.BIOMETRIC_SUCCESS)
        )
    }

    // Security: Setup biometric authentication
    private fun setupBiometricAuth() {
        executor = ContextCompat.getMainExecutor(this)
        
        promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Biometric Authentication")
            .setSubtitle("Use your fingerprint or face to continue")
            .setNegativeButtonText("Cancel")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()
        
        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    // Security: Authentication succeeded
                }

                override fun onAuthenticationFailed() {
                    // Security: Authentication failed
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Security: Authentication error
                }
            })
    }

    // Security: Authenticate user with biometrics
    private fun authenticateUser(result: MethodChannel.Result) {
        biometricPrompt.authenticate(promptInfo)
        result.success(null)
    }

    // Security: Generate secure key in hardware-backed KeyStore
    private fun generateSecureKey(alias: String) {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )
        
        val keyGenSpec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationValidityDurationSeconds(300)
            .setRandomizedEncryptionRequired(true)
            .build()
        
        keyGenerator.init(keyGenSpec)
        keyGenerator.generateKey()
    }

    // Security: Encrypt data using hardware-backed key
    private fun encryptData(alias: String, data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(
            KeyProperties.KEY_ALGORITHM_AES + "/" +
            KeyProperties.BLOCK_MODE_CBC + "/" +
            KeyProperties.ENCRYPTION_PADDING_PKCS7
        )
        
        val secretKey = keyStore.getEntry(alias, null) as KeyStore.SecretKeyEntry
        cipher.init(Cipher.ENCRYPT_MODE, secretKey.secretKey)
        
        return cipher.doFinal(data)
    }

    // Security: Decrypt data using hardware-backed key
    private fun decryptData(alias: String, data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(
            KeyProperties.KEY_ALGORITHM_AES + "/" +
            KeyProperties.BLOCK_MODE_CBC + "/" +
            KeyProperties.ENCRYPTION_PADDING_PKCS7
        )
        
        val secretKey = keyStore.getEntry(alias, null) as KeyStore.SecretKeyEntry
        cipher.init(Cipher.DECRYPT_MODE, secretKey.secretKey)
        
        return cipher.doFinal(data)
    }

    // Security: Prevent screenshots of sensitive screens
    companion object {
        private const val EXTRA_PROJECT_NAME = "sprout_project_name"
        private const val MAX_PACKAGE_BYTES = 2 * 1024 * 1024
        private const val REQUEST_TAKE_PHOTO = 4101
    }

    override fun onResume() {
        super.onResume()
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_SECURE,
            android.view.WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
