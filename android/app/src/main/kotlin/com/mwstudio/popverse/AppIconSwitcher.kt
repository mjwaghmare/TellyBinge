package com.mwstudio.popverse

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * Switches the launcher icon. MainActivity carries the default icon; each
 * alternate is an activity-alias in AndroidManifest.xml. Exactly one of them
 * is enabled at a time, so choosing an alternate disables MainActivity to hide
 * its launcher entry.
 *
 * Because MainActivity can be disabled, never start it by class name: use
 * [launchComponent], which resolves through whichever entry is enabled.
 */
object AppIconSwitcher {
    const val CHANNEL = "com.mwstudio.popverse/app_icon"

    /** Name reported for the default icon (MainActivity itself). */
    const val DEFAULT = "MainActivity"

    private fun className(simpleName: String) =
        "${MainActivity::class.java.`package`!!.name}.$simpleName"

    private fun mainActivity(context: Context) = ComponentName(context, MainActivity::class.java)

    /** Every alternate-icon alias declared in the manifest. */
    private fun aliases(context: Context): List<ActivityInfo> {
        val flags = PackageManager.GET_ACTIVITIES or PackageManager.GET_DISABLED_COMPONENTS
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, flags)
        }
        return info.activities?.filter { it.targetActivity != null }.orEmpty()
    }

    private fun isEnabled(context: Context, component: ComponentName, manifestDefault: Boolean): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> manifestDefault
            else -> false
        }

    private fun enabledAliases(context: Context): List<ActivityInfo> =
        aliases(context).filter { isEnabled(context, ComponentName(context, it.name), it.enabled) }

    private fun setEnabled(context: Context, component: ComponentName, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            component,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    /** Simple name of the active icon: an alias name, or [DEFAULT]. */
    fun current(context: Context): String =
        enabledAliases(context).firstOrNull()?.name?.substringAfterLast('.') ?: DEFAULT

    /**
     * Makes [simpleName] (an alias, or [DEFAULT]) the only launcher entry.
     * Returns false for a name the manifest doesn't declare.
     */
    fun apply(context: Context, simpleName: String): Boolean {
        val all = aliases(context)
        if (simpleName == DEFAULT) {
            // Enable first so the app is never left without a launcher entry.
            setEnabled(context, mainActivity(context), true)
            for (alias in all) setEnabled(context, ComponentName(context, alias.name), false)
        } else {
            val target = className(simpleName)
            if (all.none { it.name == target }) return false
            setEnabled(context, ComponentName(context, target), true)
            for (alias in all) {
                if (alias.name != target) setEnabled(context, ComponentName(context, alias.name), false)
            }
            setEnabled(context, mainActivity(context), false)
        }
        refreshWidgets(context)
        return true
    }

    /** The enabled launcher entry, to target when starting the app explicitly. */
    fun launchComponent(context: Context): ComponentName =
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.component
            ?: mainActivity(context)

    /**
     * Leaves exactly one launcher entry enabled. Covers states an interrupted
     * switch could leave behind (e.g. the process killed between steps).
     */
    fun reconcile(context: Context) {
        val enabled = enabledAliases(context)
        val mainEnabled = isEnabled(context, mainActivity(context), true)
        when {
            enabled.isEmpty() && !mainEnabled -> apply(context, DEFAULT)
            enabled.size > 1 || (enabled.isNotEmpty() && mainEnabled) ->
                apply(context, enabled.first().name.substringAfterLast('.'))
        }
    }

    /** Widgets hold a PendingIntent to the old launcher entry; rebuild them. */
    private fun refreshWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, UpNextWidgetProvider::class.java))
        if (ids.isEmpty()) return
        context.sendBroadcast(
            Intent(context, UpNextWidgetProvider::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
        )
    }
}
