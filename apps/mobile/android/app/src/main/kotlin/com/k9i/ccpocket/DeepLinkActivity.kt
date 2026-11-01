package com.k9i.ccpocket

import android.app.Activity
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log

/**
 * Receives external deep links without creating a second Flutter engine inside
 * the sender's task, then forwards the URI to the canonical app task.
 *
 * The launcher starts [MainActivity] through an activity-alias
 * (`.MainActivityDefault` or a supporter icon alias). Android matches
 * `FLAG_ACTIVITY_SINGLE_TOP` against the component the running activity was
 * started with, so forwarding to `.MainActivity` directly would create a
 * second activity that evicts the first from the cached Flutter engine
 * instead of delivering the URI via `onNewIntent` (app_links `uriLinkStream`).
 * We therefore forward to the component the running task was started with,
 * falling back to the enabled launcher alias and finally `.MainActivity`.
 */
class DeepLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val sourceIntent = intent
        val uri = sourceIntent.data
        val supported = sourceIntent.action == Intent.ACTION_VIEW &&
            uri?.scheme == SCHEME &&
            uri.host in SUPPORTED_HOSTS

        if (supported && uri != null) {
            forward(uri)
        }

        finish()
    }

    private fun forward(uri: Uri) {
        for (component in candidateComponents()) {
            val mainIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                this.component = component
                // CLEAR_TOP + SINGLE_TOP (with launchMode="singleTop") reuses
                // the existing instance via onNewIntent instead of recreating
                // it, and drops anything stacked above it in the task.
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            try {
                startActivity(mainIntent)
                return
            } catch (error: ActivityNotFoundException) {
                // e.g. the alias of an old task was disabled by an icon change.
                Log.w(TAG, "Cannot forward deep link to $component", error)
            }
        }
    }

    /** Ordered, de-duplicated targets to try for delivering the URI. */
    private fun candidateComponents(): List<ComponentName> {
        val candidates = LinkedHashSet<ComponentName>()
        runningMainComponent()?.let(candidates::add)
        packageManager.getLaunchIntentForPackage(packageName)?.component
            ?.let(candidates::add)
        candidates.add(ComponentName(this, MainActivity::class.java))
        return candidates.toList()
    }

    /**
     * Component (alias or `.MainActivity`) that started an existing app task,
     * so SINGLE_TOP matches the running activity record.
     */
    private fun runningMainComponent(): ComponentName? {
        val activityManager = getSystemService(ActivityManager::class.java)
            ?: return null
        val deepLinkComponent = ComponentName(this, DeepLinkActivity::class.java)
        return try {
            activityManager.appTasks
                .mapNotNull { task -> task.taskInfo.baseIntent.component }
                .firstOrNull { component ->
                    component.packageName == packageName &&
                        component != deepLinkComponent
                }
        } catch (error: RuntimeException) {
            // Tasks can disappear while we inspect them.
            Log.w(TAG, "Cannot inspect app tasks", error)
            null
        }
    }

    private companion object {
        const val TAG = "DeepLinkActivity"
        const val SCHEME = "ccpocket"
        val SUPPORTED_HOSTS = setOf("connect", "session")
    }
}
