# SPDX-License-Identifier: GPL-3.0-or-later
if(NOT IOS)
  message(FATAL_ERROR "FreeKillIOS.cmake requires an iOS toolchain")
endif()
enable_language(OBJCXX)
# miniaudio uses AVAudioSession Objective-C calls on iOS.
set_source_files_properties(
  "${PROJECT_SOURCE_DIR}/thirdparty/soloud/src/backend/miniaudio/soloud_miniaudio.cpp"
  TARGET_DIRECTORY soloud PROPERTIES LANGUAGE OBJCXX)
set_property(TARGET soloud PROPERTY OBJCXX_STANDARD 17)
set_target_properties(FreeKill PROPERTIES
  MACOSX_BUNDLE TRUE
  MACOSX_BUNDLE_GUI_IDENTIFIER org.freekill.ipad
  MACOSX_BUNDLE_BUNDLE_VERSION 2
  MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
  MACOSX_BUNDLE_INFO_PLIST "${PROJECT_SOURCE_DIR}/ios/Info.plist.in"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "2"
  XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS "iphoneos"
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
  XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
)
target_sources(libFreeKill PRIVATE "${PROJECT_SOURCE_DIR}/ios/runtime.mm")
set_source_files_properties("${PROJECT_SOURCE_DIR}/ios/runtime.mm" PROPERTIES
  SKIP_PRECOMPILE_HEADERS ON)
target_include_directories(libFreeKill BEFORE PRIVATE "${FK_IOS_DEPS}/include")
target_include_directories(libFreeKill PRIVATE "${PROJECT_SOURCE_DIR}/ios")
target_link_libraries(libFreeKill PRIVATE
  "-framework Foundation" "-framework Security" "-framework CoreFoundation"
  iconv z)
target_link_libraries(soloud PRIVATE
  "-framework AudioToolbox" "-framework CoreAudio" "-framework CoreFoundation"
  "-framework AVFoundation")

# The real UI remains on disk for FreeKill's Lua/QML package system. This small
# module makes its Qt imports visible to the static iOS QML plugin scanner.
set_source_files_properties("${PROJECT_SOURCE_DIR}/ios/ImportBootstrap.qml" PROPERTIES
  QT_RESOURCE_ALIAS "ImportBootstrap.qml")
qt_add_qml_module(FreeKill
  URI FreeKillIOSBootstrap
  VERSION 1.0
  QML_FILES "${PROJECT_SOURCE_DIR}/ios/ImportBootstrap.qml"
)
target_link_libraries(FreeKill PRIVATE Qt6::Svg)
# Link and embed the FFmpeg device frameworks shipped with Qt Multimedia.
# The user signs the complete bundle after downloading the IPA.
set(QT_NO_FFMPEG_XCODE_EMBED_FRAMEWORKS_CODE_SIGN_ON_COPY ON)
qt_add_ios_ffmpeg_libraries(FreeKill)
set_source_files_properties("${PROJECT_SOURCE_DIR}/image/icon.png" PROPERTIES
  MACOSX_PACKAGE_LOCATION ".")
target_sources(FreeKill PRIVATE "${PROJECT_SOURCE_DIR}/image/icon.png")
