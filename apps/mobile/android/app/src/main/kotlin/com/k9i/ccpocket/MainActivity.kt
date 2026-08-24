package com.k9i.ccpocket

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val APP_ICON_CHANNEL = "ccpocket/app_icon"
private const val FILE_PICKER_CHANNEL = "ccpocket/file_picker"
private const val MAX_FILE_BYTES = 10 * 1024 * 1024L
private const val MAX_FILES_TOTAL_BYTES = 20 * 1024 * 1024L
private const val MAX_FILE_COUNT = 5
private const val FILE_PICKER_REQUEST_CODE = 0xCCF1

class MainActivity : FlutterActivity() {
    private var pendingFilePickerResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICKER_REQUEST_CODE) return
        val result = pendingFilePickerResult ?: return
        pendingFilePickerResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val uris = buildList {
            val clipData = data?.clipData
            if (clipData != null) {
                for (index in 0 until clipData.itemCount) {
                    add(clipData.getItemAt(index).uri)
                }
            } else {
                data?.data?.let(::add)
            }
        }.distinct()
        if (uris.isEmpty()) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        Thread {
            try {
                val files = readSelectedFiles(uris.take(MAX_FILE_COUNT))
                runOnUiThread { result.success(files) }
            } catch (error: FileSelectionException) {
                runOnUiThread {
                    result.error(error.code, error.message, error.details)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("file_read_failed", error.message, null)
                }
            }
        }.start()
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
            FILE_PICKER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    if (pendingFilePickerResult != null) {
                        result.error("picker_busy", "The file picker is already open.", null)
                    } else {
                        pendingFilePickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        }
                        try {
                            startActivityForResult(intent, FILE_PICKER_REQUEST_CODE)
                        } catch (error: Exception) {
                            pendingFilePickerResult = null
                            result.error("picker_unavailable", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readSelectedFiles(uris: List<Uri>): List<Map<String, Any>> {
        val files = mutableListOf<Map<String, Any>>()
        var totalBytes = 0L
        for (uri in uris) {
            val name = displayName(uri)
            val reportedSize = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else null
            }
            if (reportedSize != null && reportedSize > MAX_FILE_BYTES) {
                throw FileSelectionException(
                    "file_too_large",
                    "$name exceeds 10 MB.",
                    mapOf("name" to name),
                )
            }
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw IllegalStateException("Unable to open $name")
            if (bytes.size.toLong() > MAX_FILE_BYTES) {
                throw FileSelectionException(
                    "file_too_large",
                    "$name exceeds 10 MB.",
                    mapOf("name" to name),
                )
            }
            totalBytes += bytes.size.toLong()
            if (totalBytes > MAX_FILES_TOTAL_BYTES) {
                throw FileSelectionException(
                    "files_too_large",
                    "Attached files exceed 20 MB total.",
                    null,
                )
            }
            files.add(
                mapOf(
                    "name" to name,
                    "mimeType" to (contentResolver.getType(uri) ?: "application/octet-stream"),
                    "bytes" to bytes,
                ),
            )
        }
        return files
    }

    private fun displayName(uri: Uri): String {
        return contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null
        } ?: uri.lastPathSegment ?: "attachment"
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

private class FileSelectionException(
    val code: String,
    override val message: String,
    val details: Map<String, String>?,
) : Exception(message)
