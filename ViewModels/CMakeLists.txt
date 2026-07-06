# ── Platform service backends ─────────────────────────────────────────────────
# Each platform service (base + subclass + compile-time create() factory) selects
# exactly one backend TU here, so only the target platform's native code links in.
# Stateless free-function hooks (Motion/Share, see PlatformHooks.h) select their
# single TU the same way.
if(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(_TENJIN_NOTIFY_BACKEND   src/NotificationService_ios.mm)
    set(_TENJIN_HAPTICS_BACKEND  src/HapticsService_ios.mm)
    set(_TENJIN_PICKER_BACKEND   src/DocumentPickerService_ios.mm)
    set(_TENJIN_TIME_BACKEND     src/TimePickerService_ios.mm)
    set(_TENJIN_MOTION_BACKEND   src/MotionService_ios.mm)
    set(_TENJIN_SHARE_BACKEND    src/ShareService_ios.mm)
elseif(ANDROID)
    set(_TENJIN_NOTIFY_BACKEND   src/NotificationService_android.cpp)
    set(_TENJIN_HAPTICS_BACKEND  src/HapticsService_android.cpp)
    # Android document picking (Storage Access Framework) and share (FileProvider)
    # are not yet implemented; the default backends keep the in-app fallbacks.
    set(_TENJIN_PICKER_BACKEND   src/DocumentPickerService_default.cpp)
    set(_TENJIN_TIME_BACKEND     src/TimePickerService_android.cpp)
    set(_TENJIN_MOTION_BACKEND   src/MotionService_android.cpp)
    set(_TENJIN_SHARE_BACKEND    src/ShareService_default.cpp)
else()
    set(_TENJIN_NOTIFY_BACKEND   src/NotificationService_default.cpp)
    set(_TENJIN_HAPTICS_BACKEND  src/HapticsService_default.cpp)
    set(_TENJIN_PICKER_BACKEND   src/DocumentPickerService_default.cpp)
    set(_TENJIN_TIME_BACKEND     src/TimePickerService_default.cpp)
    set(_TENJIN_MOTION_BACKEND   src/MotionService_default.cpp)
    set(_TENJIN_SHARE_BACKEND    src/ShareService_default.cpp)
endif()

qt_add_library(TenjinViewModels STATIC
    src/AppViewModel.cpp
    src/ContentBlockModel.cpp
    src/EntryViewModel_Lifecycle.cpp
    src/EntryViewModel_Entry.cpp
    src/EntryViewModel_Content.cpp
    src/EntryViewModel_Media.cpp
    src/EntryViewModel_Search.cpp
    src/EntryViewModel_Tag.cpp
    src/DeckListModel.cpp
    src/DeckViewModel.cpp
    src/SidebarModel.cpp
    src/SidebarViewModel.cpp
    src/ReviewViewModel.cpp
    src/FormulaRenderer.cpp

    # Platform services: shared base + selected backend TU.
    src/NotificationService.cpp
    ${_TENJIN_NOTIFY_BACKEND}
    src/HapticsService.cpp
    ${_TENJIN_HAPTICS_BACKEND}
    src/DocumentPickerService.cpp
    ${_TENJIN_PICKER_BACKEND}
    src/TimePickerService.cpp
    ${_TENJIN_TIME_BACKEND}
    src/CloudService.cpp

    # Stateless platform hooks (free functions; one TU each).
    ${_TENJIN_MOTION_BACKEND}
    ${_TENJIN_SHARE_BACKEND}

    include/ViewModels/AppViewModel.h
    include/ViewModels/EntryViewModel.h
    include/ViewModels/DeckViewModel.h
    include/ViewModels/ReviewViewModel.h
    include/ViewModels/SidebarViewModel.h
    include/ViewModels/LogViewModel.h
    include/ViewModels/FormulaRenderer.h
    include/ViewModels/NotificationService.h
    include/ViewModels/HapticsService.h
    include/ViewModels/DocumentPickerService.h
    include/ViewModels/CloudService.h
    include/ViewModels/PlatformHooks.h
    include/ViewModels/TimePickerService.h
)

target_include_directories(TenjinViewModels PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_definitions(TenjinViewModels
    PUBLIC ${TENJIN_FEATURE_DEFINITIONS}
)

target_link_libraries(TenjinViewModels
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Network
        EntryService
        DeckService
    PRIVATE
        tenjin_warnings
        tenjin_sanitizers
)

# iOS frameworks: notifications (UserNotifications), share/picker (UIKit),
# document types (UniformTypeIdentifiers).
if(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(TenjinViewModels PRIVATE
        "-framework UserNotifications"
        "-framework UIKit"
        "-framework UniformTypeIdentifiers"
        "-framework PhotosUI"
        "-framework Photos")
endif()

# Android: runtime notification permission + JNI use QtAndroidPrivate/CorePrivate.
if(ANDROID)
    find_package(Qt6 6.9 REQUIRED COMPONENTS CorePrivate)
    target_link_libraries(TenjinViewModels PRIVATE Qt6::CorePrivate)
endif()
