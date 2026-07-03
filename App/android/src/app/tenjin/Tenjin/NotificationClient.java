package app.tenjin.Tenjin;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;

// Minimal local-notification helper invoked from C++ via QJniObject. Posts an
// immediate notification on the "tenjin_reminders" channel. Daily scheduling is
// handled on the Qt/C++ side (NotificationService's timer), so this only needs
// to display a notification when called.
public class NotificationClient
{
    private static final String CHANNEL_ID = "tenjin_reminders";
    private static int s_nextId = 1;

    public static void notify(Context context, String title, String message)
    {
        if (context == null)
            return;

        NotificationManager manager =
            (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null)
            return;

        Notification.Builder builder;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, "Review reminders", NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Daily reminders to review your cards");
            manager.createNotificationChannel(channel);
            builder = new Notification.Builder(context, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(context);
        }

        builder.setContentTitle(title)
               .setContentText(message)
               .setSmallIcon(context.getApplicationInfo().icon)
               .setAutoCancel(true);

        manager.notify(s_nextId++, builder.build());
    }
}
