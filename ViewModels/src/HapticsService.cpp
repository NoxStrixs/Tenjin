#include <ViewModels/HapticsService.h>

HapticsService::HapticsService(QObject* parent) : QObject(parent) {}
HapticsService::~HapticsService() = default;

void HapticsService::setEnabled(bool v)
{
    if (m_enabled == v)
        return;
    m_enabled = v;
    emit enabledChanged();
}

void HapticsService::light()
{
    play(0);
}
void HapticsService::medium()
{
    play(1);
}
void HapticsService::heavy()
{
    play(2);
}
void HapticsService::success()
{
    play(3);
}
void HapticsService::warning()
{
    play(4);
}

void HapticsService::play(int level)
{
    if (!m_enabled)
        return;
    playImpl(level);
}

// No-op default; platform subclasses override playImpl().
void HapticsService::playImpl(int /*level*/) {}
