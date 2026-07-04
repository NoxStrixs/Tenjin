// HapticsService_default.cpp — desktop / fallback backend.
// Compiled on every platform except iOS and Android. No haptic hardware assumed;
// the base no-op playImpl() is inherited unchanged.

#include <ViewModels/HapticsService.h>

namespace {

class HapticsServiceDefault final : public HapticsService
{
public:
    using HapticsService::HapticsService;
    // Inherits the base no-op playImpl().
};

} // namespace

std::unique_ptr<HapticsService> HapticsService::create(QObject* parent)
{
    return std::make_unique<HapticsServiceDefault>(parent);
}
