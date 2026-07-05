package app.tenjin.Tenjin;

import android.app.Activity;
import android.app.TimePickerDialog;
import android.text.format.DateFormat;

// Shows the system TimePickerDialog and routes the result back to C++ via a
// JNI native callback. Presented on the UI thread (required for dialogs).
public final class TimePickerClient {

    // Implemented in C++ (TimePickerService_android.cpp) via RegisterNatives.
    private static native void onTimePicked(int hour, int minute);
    private static native void onTimeCancelled();

    public static void show(final Activity activity, final int hour, final int minute) {
        if (activity == null) {
            onTimeCancelled();
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                final boolean is24h = DateFormat.is24HourFormat(activity);
                TimePickerDialog dialog = new TimePickerDialog(
                    activity,
                    new TimePickerDialog.OnTimeSetListener() {
                        @Override
                        public void onTimeSet(android.widget.TimePicker view,
                                              int hourOfDay, int min) {
                            onTimePicked(hourOfDay, min);
                        }
                    },
                    hour, minute, is24h);
                dialog.setOnCancelListener(d -> onTimeCancelled());
                dialog.show();
            }
        });
    }
}
