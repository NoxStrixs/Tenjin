package app.tenjin.Tenjin;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import java.util.Calendar;

// Schedules the repeating daily review reminder with AlarmManager so it fires
// even when the app is not running. Invoked from C++ (NotificationService_
// android.cpp) via QJniObject. AlarmManager does not natively repeat with
// exact+allowWhileIdle, so the receiver reschedules the next occurrence each
// time it fires (see ReminderReceiver).
public final class AlarmScheduler {

    private static final int REQUEST_CODE = 1001;

    public static void schedule(Context context, int hour, int minute,
                                String title, String body) {
        if (context == null) return;
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;

        PendingIntent pi = buildPendingIntent(context, hour, minute, title, body);

        // Next occurrence of hour:minute (today if still ahead, else tomorrow).
        Calendar now = Calendar.getInstance();
        Calendar next = Calendar.getInstance();
        next.set(Calendar.HOUR_OF_DAY, hour);
        next.set(Calendar.MINUTE, minute);
        next.set(Calendar.SECOND, 0);
        next.set(Calendar.MILLISECOND, 0);
        if (!next.after(now)) {
            next.add(Calendar.DAY_OF_MONTH, 1);
        }

        long triggerAt = next.getTimeInMillis();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi);
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi);
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pi);
        }
    }

    public static void cancel(Context context) {
        if (context == null) return;
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.cancel(buildPendingIntent(context, 0, 0, "", ""));
    }

    private static PendingIntent buildPendingIntent(Context context, int hour, int minute,
                                                    String title, String body) {
        Intent intent = new Intent(context, ReminderReceiver.class);
        intent.setAction(ReminderReceiver.ACTION_FIRE);
        intent.putExtra(ReminderReceiver.EXTRA_TITLE, title);
        intent.putExtra(ReminderReceiver.EXTRA_BODY, body);
        intent.putExtra(ReminderReceiver.EXTRA_HOUR, hour);
        intent.putExtra(ReminderReceiver.EXTRA_MINUTE, minute);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags);
    }
}
