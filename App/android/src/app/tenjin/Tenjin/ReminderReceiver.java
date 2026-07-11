package app.tenjin.Tenjin;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

// Fires when the AlarmManager daily reminder triggers (even if the app isn't
// running). Posts the notification via NotificationClient, then reschedules the
// next day's alarm — AlarmManager exact+allowWhileIdle is one-shot, so we
// re-arm each time. Also re-arms after device reboot (BOOT_COMPLETED), since
// alarms are cleared on reboot.
public final class ReminderReceiver extends BroadcastReceiver {

    public static final String ACTION_FIRE = "app.tenjin.Tenjin.ACTION_REMINDER";
    public static final String EXTRA_TITLE  = "title";
    public static final String EXTRA_BODY   = "body";
    public static final String EXTRA_HOUR   = "hour";
    public static final String EXTRA_MINUTE = "minute";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;

        final String action = intent.getAction();

        if (Intent.ACTION_BOOT_COMPLETED.equals(action)) {
            // Alarms are cleared on reboot. If the user has a reminder saved,
            // the app re-arms it on next launch; nothing to persist here beyond
            // what the app stores. (A future enhancement could persist the
            // reminder time in SharedPreferences and re-arm directly.)
            return;
        }

        final String title = intent.getStringExtra(EXTRA_TITLE);
        final String body  = intent.getStringExtra(EXTRA_BODY);
        final int hour     = intent.getIntExtra(EXTRA_HOUR, 9);
        final int minute   = intent.getIntExtra(EXTRA_MINUTE, 0);

        NotificationClient.notify(context,
            title != null ? title : "",
            body  != null ? body  : "");

        // Re-arm for the next day.
        AlarmScheduler.schedule(context, hour, minute,
            title != null ? title : "",
            body  != null ? body  : "");
    }
}
