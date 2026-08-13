package com.sproutapp.sprout

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
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
    
    // Security: KeyStore for cryptographic operations
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply {
        load(null)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> result.notImplemented()
            }
        }
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
    override fun onResume() {
        super.onResume()
        window.setFlags(
            android.view.WindowManager.LayoutParams.FLAG_SECURE,
            android.view.WindowManager.LayoutParams.FLAG_SECURE
        )
    }
}
