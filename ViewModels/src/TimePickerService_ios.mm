// iOS backend: UIDatePicker (.time) hosted in a modally-presented view
// controller with Done/Cancel. iOS has no standalone time-picker dialog, so we
// host the picker ourselves. The wheels/locale (12h/24h) come from the system.
// Compiled only on iOS.

#include <ViewModels/TimePickerService.h>

#include <QString>

#import <UIKit/UIKit.h>

#include <functional>

// Hosts a UIDatePicker in .time mode with a Done/Cancel bar. std::function
// callbacks avoid holding a namespace-scoped C++ pointer in an ObjC property.
@interface TenjinTimePickerVC : UIViewController
@property(nonatomic, strong) UIDatePicker* picker;
@property(nonatomic) std::function<void(int, int)> onPicked;
@property(nonatomic) std::function<void()>          onCancelled;
@end

@implementation TenjinTimePickerVC

- (void)loadView
{
    UIView* root = [[UIView alloc] init];
    root.backgroundColor = [UIColor systemBackgroundColor];
    self.view = root;

    self.picker = [[UIDatePicker alloc] init];
    self.picker.datePickerMode = UIDatePickerModeTime;
    self.picker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    self.picker.translatesAutoresizingMaskIntoConstraints = NO;

    UIToolbar* bar = [[UIToolbar alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    UIBarButtonItem* cancel =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self action:@selector(onCancel)];
    UIBarButtonItem* flex =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                      target:nil action:nil];
    UIBarButtonItem* done =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self action:@selector(onDone)];
    bar.items = @[ cancel, flex, done ];

    [root addSubview:bar];
    [root addSubview:self.picker];
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:root.safeAreaLayoutGuide.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.picker.topAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [self.picker.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
    ]];
}

- (void)onDone
{
    NSDateComponents* comps =
        [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                        fromDate:self.picker.date];
    if (self.onPicked)
        self.onPicked(static_cast<int>(comps.hour), static_cast<int>(comps.minute));
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onCancel
{
    if (self.onCancelled) self.onCancelled();
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

namespace {

UIViewController* keyRootViewController()
{
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene* ws = static_cast<UIWindowScene*>(scene);
        for (UIWindow* w in ws.windows) {
            if (w.isKeyWindow) return w.rootViewController;
        }
    }
    return nil;
}

class TimePickerServiceIos final : public TimePickerService
{
public:
    explicit TimePickerServiceIos(QObject* parent) : TimePickerService(parent) {}

protected:
    void pickTimeNative(int hour, int minute) override
    {
        UIViewController* root = keyRootViewController();
        if (!root) { emit pickCancelled(); return; }

        TenjinTimePickerVC* vc = [[TenjinTimePickerVC alloc] init];
        vc.modalPresentationStyle = UIModalPresentationFormSheet;
        vc.onPicked    = [this](int h, int m) { emit timePicked(h, m); };
        vc.onCancelled = [this]() { emit pickCancelled(); };

        // Seed the picker with the current reminder time (today's date + h:m).
        [vc loadViewIfNeeded];
        NSDateComponents* comps = [[NSDateComponents alloc] init];
        comps.hour = hour;
        comps.minute = minute;
        NSDate* seed = [[NSCalendar currentCalendar] dateFromComponents:comps];
        if (seed) vc.picker.date = seed;

        [root presentViewController:vc animated:YES completion:nil];
    }

    bool hasNativePickerImpl() const override { return true; }
};

} // namespace

std::unique_ptr<TimePickerService> TimePickerService::create(QObject* parent)
{
    return std::make_unique<TimePickerServiceIos>(parent);
}
