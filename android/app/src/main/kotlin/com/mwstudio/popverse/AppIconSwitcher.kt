package com.mwstudio.popverse

import android.content.ComponentName
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build

/**
 * Switches the launcher icon by enabling exactly one of the activity-aliases
 * declared in AndroidManifest.xml. MainActivity itself is never disabled, so
 * explicit intents to it (home widget taps, notifications) keep working.
 */
object AppIconSwitcher {
    const val CHANNEL = "com.mwstudio.popverse/app_icon"
    private const val DEFAULT_ALIAS = "MainActivityDefault"

    private fun className(simpleName: String) =
        "${MainActivity::class.java.`package`!!.name}.$simpleName"

    /** Every launcher alias declared in the manifest. */
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

    private fun isEnabled(context: Context, activity: ActivityInfo): Boolean =
        when (context.packageManager.getComponentEnabledSetting(ComponentName(context, activity.name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> activity.enabled
            else -> false
        }

    private fun setEnabled(context: Context, name: String, enabled: Boolean) {
        context.packageManager.setComponentEnabledSetting(
            ComponentName(context, name),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }

    /** Simple name of the enabled alias, e.g. "MainActivityMidnight". */
    fun current(context: Context): String? {
        val enabled = aliases(context).filter { isEnabled(context, it) }
        val alias = enabled.firstOrNull { !it.name.endsWith(".$DEFAULT_ALIAS") } ?: enabled.firstOrNull()
        return alias?.name?.substringAfterLast('.')
    }

    /** Enables [simpleName] and disables every other alias. Applies immediately. */
    fun apply(context: Context, simpleName: String): Boolean {
        val target = className(simpleName)
        val all = aliases(context)
        if (all.none { it.name == target }) return false
        // Enable first so the app is never left without a launcher entry.
        setEnabled(context, target, true)
        for (alias in all) {
            if (alias.name != target && isEnabled(context, alias)) setEnabled(context, alias.name, false)
        }
        return true
    }

    /**
     * Repairs state left by the old flutter_dynamic_icon_plus flow, which
     * disabled MainActivity and could leave an alias enabled alongside the
     * default one after this update. Keeps a chosen alternate icon if any.
     */
    fun reconcile(context: Context) {
        val main = ComponentName(context, MainActivity::class.java)
        val pm = context.packageManager
        if (pm.getComponentEnabledSetting(main) == PackageManager.COMPONENT_ENABLED_STATE_DISABLED) {
            pm.setComponentEnabledSetting(main, PackageManager.COMPONENT_ENABLED_STATE_DEFAULT, PackageManager.DONT_KILL_APP)
        }
        val enabled = aliases(context).filter { isEnabled(context, it) }
        when {
            enabled.isEmpty() -> setEnabled(context, className(DEFAULT_ALIAS), true)
            enabled.size > 1 -> apply(context, current(context) ?: DEFAULT_ALIAS)
        }
    }
}
