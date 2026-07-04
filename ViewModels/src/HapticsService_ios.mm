// HapticsService_ios.mm — iOS backend using UIKit feedback generators.
// Compiled only on iOS. Verified against iOS 16+ UIFeedbackGenerator APIs.

#include <ViewModels/HapticsService.h>

#import <UIKit/UIKit.h>

namespace {

class HapticsServiceIos final : public HapticsService
{
public:
    using HapticsService::HapticsService;

protected:
    void playImpl(int level) override
    {
        switch (level) {
        case 0: { // light — selection change
            UISelectionFeedbackGenerator* g = [[UISelectionFeedbackGenerator alloc] init];
            [g selectionChanged];
            break;
        }
        case 1: { // medium — button press
            UIImpactFeedbackGenerator* g = [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleMedium];
            [g impactOccurred];
            break;
        }
        case 2: { // heavy — destructive action
            UIImpactFeedbackGenerator* g = [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleHeavy];
            [g impactOccurred];
            break;
        }
        case 3: { // success
            UINotificationFeedbackGenerator* g = [[UINotificationFeedbackGenerator alloc] init];
            [g notificationOccurred:UINotificationFeedbackTypeSuccess];
            break;
        }
        case 4: { // warning
            UINotificationFeedbackGenerator* g = [[UINotificationFeedbackGenerator alloc] init];
            [g notificationOccurred:UINotificationFeedbackTypeWarning];
            break;
        }
        default:
            break;
        }
    }
};

} // namespace

std::unique_ptr<HapticsService> HapticsService::create(QObject* parent)
{
    return std::make_unique<HapticsServiceIos>(parent);
}
