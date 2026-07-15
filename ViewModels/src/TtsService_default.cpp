// TtsService_default.cpp — stub for platforms without a native speech backend.
// hasTts() returns false so the UI hides the speaker affordance.

#include <ViewModels/TtsService.h>

struct TtsService::Impl {
};

TtsService::TtsService(QObject* parent) : QObject(parent), d(std::make_unique<Impl>()) {}
TtsService::~TtsService() = default;
bool TtsService::hasTts() const
{
    return false;
}
void TtsService::speak(const QString&, const QString&) {}
void TtsService::stop() {}

std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}
