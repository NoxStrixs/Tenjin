#include <ViewModels/TimePickerService.h>

void TimePickerService::pickTime(int hour, int minute)
{
    pickTimeNative(hour, minute);
}

bool TimePickerService::hasNativePicker() const
{
    return hasNativePickerImpl();
}

// Base defaults: desktop has no native picker.
void TimePickerService::pickTimeNative(int /*hour*/, int /*minute*/)
{
    emit pickCancelled();
}

bool TimePickerService::hasNativePickerImpl() const
{
    return false;
}
