QT += core gui qml quick
CONFIG += console c++17
CONFIG -= app_bundle
TEMPLATE = app
TARGET = mark-refresh-test
SOURCES += $$PWD/mark-refresh.cpp $$PWD/../ios/mark_refresh.cpp
INCLUDEPATH += $$PWD/../ios
