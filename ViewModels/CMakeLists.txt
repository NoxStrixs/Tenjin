# Platform-specific notification delivery backend. Exactly one is compiled:
# iOS uses UserNotifications (.mm), Android uses a JNI call to a Java helper,
# everything else uses the no-op default that falls back to an in-app toast.
if(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(_TENJIN_NOTIFY_BACKEND src/NotificationService_ios.mm)
    set(_TENJIN_MOTION_BACKEND src/MotionService_ios.mm)
    set(_TENJIN_SHARE_BACKEND  src/ShareService_ios.mm)
    set(_TENJIN_PICKER_BACKEND src/DocumentPickerService_ios.mm)
elseif(ANDROID)
    set(_TENJIN_NOTIFY_BACKEND src/NotificationService_android.cpp)
    set(_TENJIN_MOTION_BACKEND src/MotionService_android.cpp)
    # Android share needs a FileProvider (manifest + res/xml) before ACTION_SEND
    # can expose the file; until that lands, the default no-op keeps the
    # toast-with-path fallback.
    set(_TENJIN_SHARE_BACKEND  src/ShareService_default.cpp)
else()
    set(_TENJIN_NOTIFY_BACKEND src/NotificationService_default.cpp)
    set(_TENJIN_MOTION_BACKEND src/MotionService_default.cpp)
    set(_TENJIN_SHARE_BACKEND  src/ShareService_default.cpp)
    set(_TENJIN_PICKER_BACKEND src/DocumentPickerService_default.cpp)
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
    src/NotificationService.cpp
    ${_TENJIN_NOTIFY_BACKEND}
    ${_TENJIN_MOTION_BACKEND}
    ${_TENJIN_SHARE_BACKEND}
    ${_TENJIN_PICKER_BACKEND}
    src/CloudService.cpp
    src/HapticsService.cpp

    include/ViewModels/AppViewModel.h
    include/ViewModels/EntryViewModel.h
    include/ViewModels/DeckViewModel.h
    include/ViewModels/ReviewViewModel.h
    include/ViewModels/SidebarViewModel.h
    include/ViewModels/LogViewModel.h
    include/ViewModels/FormulaRenderer.h
    include/ViewModels/NotificationService.h
    include/ViewModels/CloudService.h
    include/ViewModels/HapticsService.h
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

# iOS: the notification backend uses the UserNotifications framework; the
# reduced-motion probe uses UIKit (UIAccessibility).
if(IOS OR CMAKE_SYSTEM_NAME STREQUAL "iOS")
    target_link_libraries(TenjinViewModels PRIVATE
        "-framework UserNotifications"
        "-framework UIKit"
        "-framework UniformTypeIdentifiers")
endif()

# Android: the notification backend uses QtAndroidPrivate (runtime permission),
# which lives in Qt6::CorePrivate.
if(ANDROID)
    find_package(Qt6 6.8 REQUIRED COMPONENTS CorePrivate)
    target_link_libraries(TenjinViewModels PRIVATE Qt6::CorePrivate)
endif()
