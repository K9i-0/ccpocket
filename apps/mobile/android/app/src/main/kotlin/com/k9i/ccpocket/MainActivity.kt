package com.k9i.ccpocket

import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

private const val APP_ICON_CHANNEL = "ccpocket/app_icon"
private const val CLIPBOARD_CHANNEL = "ccpocket/clipboard"
private const val MAX_CLIPBOARD_IMAGE_BYTES = 20 * 1024 * 1024

private val SUPPORTED_IMAGE_MIME_TYPES = listOf(
    "image/gif",
    "image/webp",
    "image/png",
    "image/jpeg",
)

private class ImageTooLargeException : IOException("Clipboard image exceeds size limit")

class MainActivity : AudioServiceActivity() {
    private val clipboardExecutor = Executors.newSingleThreadExecutor()

    // app_links owns URI delivery. FlutterActivity reads
    // `flutter_deeplinking_enabled` from the launching component, which is a
    // launcher activity-alias without that meta-data (default: true), so the
    // manifest flag alone doesn't stop Flutter from pushing the URI as a route.
    override fun shouldHandleDeeplinking(): Boolean = false

    override fun onDestroy() {
        clipboardExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_ICON_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "supportsAlternateIcons" -> result.success(true)
                "getCurrentIcon" -> result.success(getCurrentIcon())
                "setIcon" -> {
                    val icon = call.argument<String>("icon")
                    try {
                        setLauncherIcon(icon)
                        result.success(null)
                    } catch (error: IllegalArgumentException) {
                        result.error("invalid_icon", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CLIPBOARD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasImage" -> result.success(hasClipboardImage())
                "readImage" -> readClipboardImage(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasClipboardImage(): Boolean {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            ?: return false
        if (!clipboard.hasPrimaryClip()) return false
        // Inspect ClipDescription only (metadata) to avoid Android 12+ paste toast.
        val description = clipboard.primaryClipDescription ?: return false
        return SUPPORTED_IMAGE_MIME_TYPES.any { description.hasMimeType(it) } ||
            description.hasMimeType("image/jpg")
    }

    private fun readClipboardImage(result: MethodChannel.Result) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        if (clipboard == null || !clipboard.hasPrimaryClip()) {
            result.success(null)
            return
        }
        val clip = try {
            clipboard.primaryClip
        } catch (error: SecurityException) {
            result.error("clipboard_read_failed", error.message, null)
            return
        }
        if (clip == null || clip.itemCount == 0) {
            result.success(null)
            return
        }

        val uris = mutableListOf<Uri>()
        for (index in 0 until clip.itemCount) {
            clip.getItemAt(index)?.uri?.let { uris.add(it) }
        }
        if (uris.isEmpty()) {
            result.success(null)
            return
        }

        if (clipboardExecutor.isShutdown) {
            result.success(null)
            return
        }
        try {
            clipboardExecutor.execute {
                try {
                    val payload = readFirstSupportedImage(uris)
                    runOnUiThread { result.success(payload) }
                } catch (error: ImageTooLargeException) {
                    runOnUiThread { result.error("image_load_failed", error.message, null) }
                } catch (error: SecurityException) {
                    runOnUiThread { result.error("image_load_failed", error.message, null) }
                } catch (error: IOException) {
                    runOnUiThread { result.error("image_load_failed", error.message, null) }
                } catch (error: RuntimeException) {
                    runOnUiThread { result.error("clipboard_read_failed", error.message, null) }
                }
            }
        } catch (_: RejectedExecutionException) {
            result.success(null)
        }
    }

    private fun readFirstSupportedImage(uris: List<Uri>): Map<String, Any>? {
        val resolver = applicationContext.contentResolver
        for (uri in uris) {
            val streamTypes = resolver.getStreamTypes(uri, "image/*")?.toList().orEmpty()
            for (preferredMime in SUPPORTED_IMAGE_MIME_TYPES) {
                val matchingStreamType = streamTypes.firstOrNull {
                    normalizeImageMimeType(it) == preferredMime
                }
                if (matchingStreamType != null) {
                    val bytes = openTypedStreamBytes(uri, matchingStreamType) ?: continue
                    val resolvedMime = detectImageMimeType(bytes) ?: preferredMime
                    if (resolvedMime in SUPPORTED_IMAGE_MIME_TYPES) {
                        return mapOf("bytes" to bytes, "mimeType" to resolvedMime)
                    }
                }
            }

            val contentType = normalizeImageMimeType(resolver.getType(uri))
            if (contentType != null &&
                (contentType in SUPPORTED_IMAGE_MIME_TYPES || contentType == "image/*")
            ) {
                val bytes = resolver.openInputStream(uri)?.use { readBoundedBytes(it) } ?: continue
                if (bytes.isEmpty()) continue
                val resolvedMime = detectImageMimeType(bytes)
                    ?: contentType.takeIf { it in SUPPORTED_IMAGE_MIME_TYPES }
                if (resolvedMime != null) {
                    return mapOf("bytes" to bytes, "mimeType" to resolvedMime)
                }
            }
        }
        return null
    }

    private fun openTypedStreamBytes(uri: Uri, mimeType: String): ByteArray? {
        val resolver = applicationContext.contentResolver
        val afd = resolver.openTypedAssetFileDescriptor(uri, mimeType, null)
        if (afd != null) {
            return afd.use { descriptor ->
                descriptor.createInputStream().use { readBoundedBytes(it) }
            }.takeIf { it.isNotEmpty() }
        }
        return resolver.openInputStream(uri)?.use { readBoundedBytes(it) }
            ?.takeIf { it.isNotEmpty() }
    }

    private fun readBoundedBytes(input: InputStream): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        var total = 0
        while (true) {
            val read = input.read(buffer)
            if (read == -1) break
            total += read
            if (total > MAX_CLIPBOARD_IMAGE_BYTES) {
                throw ImageTooLargeException()
            }
            output.write(buffer, 0, read)
        }
        return output.toByteArray()
    }

    private fun normalizeImageMimeType(mimeType: String?): String? {
        val lower = mimeType?.trim()?.lowercase() ?: return null
        return if (lower == "image/jpg") "image/jpeg" else lower
    }

    private fun detectImageMimeType(bytes: ByteArray): String? {
        if (bytes.size >= 4 &&
            bytes[0] == 0x47.toByte() &&
            bytes[1] == 0x49.toByte() &&
            bytes[2] == 0x46.toByte() &&
            bytes[3] == 0x38.toByte()
        ) {
            return "image/gif"
        }
        if (bytes.size >= 12 &&
            bytes[0] == 0x52.toByte() &&
            bytes[1] == 0x49.toByte() &&
            bytes[2] == 0x46.toByte() &&
            bytes[3] == 0x46.toByte() &&
            bytes[8] == 0x57.toByte() &&
            bytes[9] == 0x45.toByte() &&
            bytes[10] == 0x42.toByte() &&
            bytes[11] == 0x50.toByte()
        ) {
            return "image/webp"
        }
        if (bytes.size >= 8 &&
            bytes[0] == 0x89.toByte() &&
            bytes[1] == 0x50.toByte() &&
            bytes[2] == 0x4E.toByte() &&
            bytes[3] == 0x47.toByte()
        ) {
            return "image/png"
        }
        if (bytes.size >= 3 &&
            bytes[0] == 0xFF.toByte() &&
            bytes[1] == 0xD8.toByte() &&
            bytes[2] == 0xFF.toByte()
        ) {
            return "image/jpeg"
        }
        return null
    }

    private fun getCurrentIcon(): String? {
        val aliases = mapOf(
            "$packageName.MainActivitySupporterLightOutline" to "light_outline",
            "$packageName.MainActivitySupporterProCopperEmerald" to "pro_copper_emerald",
        )

        for ((alias, iconId) in aliases) {
            val state = packageManager.getComponentEnabledSetting(
                ComponentName(packageName, alias),
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return iconId
            }
        }
        return null
    }

    private fun setLauncherIcon(icon: String?) {
        val targetAlias = when (icon) {
            null, "default" -> "$packageName.MainActivityDefault"
            "light_outline" -> "$packageName.MainActivitySupporterLightOutline"
            "pro_copper_emerald" -> "$packageName.MainActivitySupporterProCopperEmerald"
            else -> throw IllegalArgumentException("Unknown app icon: $icon")
        }
        val aliases = listOf(
            "$packageName.MainActivityDefault",
            "$packageName.MainActivitySupporterLightOutline",
            "$packageName.MainActivitySupporterProCopperEmerald",
        )

        for (alias in aliases) {
            packageManager.setComponentEnabledSetting(
                ComponentName(packageName, alias),
                if (alias == targetAlias) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                },
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
