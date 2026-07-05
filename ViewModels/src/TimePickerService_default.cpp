// Desktop / fallback backend. No native time picker: inherits the base
// pickCancelled() default so QML uses inline text entry.

#include <ViewModels/TimePickerService.h>

namespace {

class TimePickerServiceDefault final : public TimePickerService
{
public:
    using TimePickerService::TimePickerService;
};

} // namespace

std::unique_ptr<TimePickerService> TimePickerService::create(QObject* parent)
{
    return std::make_unique<TimePickerServiceDefault>(parent);
}
