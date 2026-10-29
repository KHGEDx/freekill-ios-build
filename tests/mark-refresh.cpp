// SPDX-License-Identifier: GPL-3.0-or-later
#include "runtime.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QDebug>
#include <QGuiApplication>
#include <QMetaObject>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QVariant>
#include <cstdio>
#include <cstdlib>

static void check(bool ok, const char *message) {
  if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
static void writeFile(const QString &path, const QByteArray &contents) {
  check(QDir().mkpath(QFileInfo(path).absolutePath()), "create fixture directory");
  QFile file(path);
  check(file.open(QIODevice::WriteOnly), "open fixture");
  check(file.write(contents) == contents.size(), "write fixture");
}
static QByteArray readFile(const QString &path) {
  QFile file(path);
  check(file.open(QIODevice::ReadOnly), "read fixture");
  return file.readAll();
}
static QVariant invoke(QObject *root, const char *method, const QVariant &value = {}) {
  QVariant result;
  const bool ok = value.isValid()
      ? QMetaObject::invokeMethod(root, method, Q_RETURN_ARG(QVariant, result), Q_ARG(QVariant, value))
      : QMetaObject::invokeMethod(root, method, Q_RETURN_ARG(QVariant, result));
  check(ok, method);
  for (int i = 0; i < 5; ++i) QCoreApplication::processEvents();
  return result;
}

static const QByteArray fakeLua = R"QML(pragma Singleton
import QtQml
QtObject {
  property int customValue: 0
  function tr(value) { return String(value); }
  function createProxy(exp) { return {}; }
  function getQmlMark(type, mark, player) {
    return {text: String(customValue), qml: {uri: "Test", name: "Detail", prop: {counter: customValue}}};
  }
})QML";

static const QByteArray probeQml = R"QML(import QtQuick
import Fk
import LunarLtk 1.0
Item {
  id: root
  property list<var> marks: []
  property list<var> picMarks: []
  property list<var> otherMarks: []
  Repeater {
    id: normal
    model: root.marks
    delegate: Text { required property var modelData; text: String(modelData.value) }
  }
  Repeater {
    id: pictures
    model: root.picMarks
    delegate: Text { required property var modelData; text: String(modelData.value) }
  }
  Repeater {
    id: others
    model: root.otherMarks
    delegate: Text { required property var modelData; text: String(modelData.value) }
  }
  function setNumeric(n) { Ltk.setMark(marks, "@mobile_import__hunting", n, 1); return true; }
  function setPicture(n) { Ltk.setMark(picMarks, "@!test", n, 1); return true; }
  function setOther(n) { Ltk.setMark(otherMarks, "@mobile_import__hunting", n, 2); return true; }
  function setCustom(n) { Lua.customValue = n; Ltk.setMark(marks, "@[test]custom", n, 1); return true; }
  function setList(n) { Ltk.setMark(marks, "@list", n === 1 ? ["slash"] : ["slash", "jink"], 1); return true; }
  function numericText() { return normal.count ? normal.itemAt(0).text : "empty"; }
  function pictureText() { return pictures.count ? pictures.itemAt(0).text : "empty"; }
  function otherText() { return others.count ? others.itemAt(0).text : "empty"; }
  function lastText() { return normal.itemAt(normal.count - 1).text; }
  function customMetadata() { return marks[1].qml.prop.counter; }
  function addMetadata() {
    const elem = marks[0];
    elem.annotation = "retained";
    marks.splice(0, 1, elem);
    return true;
  }
  function metadata() { return marks[0].annotation; }
})QML";

static void runCase(const QByteArray &source, const QString &relative, bool enabled) {
  QTemporaryDir fixture;
  check(fixture.isValid(), "temporary fixture");
  const QString base = fixture.path() + "/" + relative;
  const QString util = base + "/LunarLtk/LtkLuaUtil.qml";
  writeFile(util, source);
  writeFile(base + "/LunarLtk/qmldir", "module LunarLtk\nsingleton Ltk 1.0 LtkLuaUtil.qml\n");
  writeFile(base + "/Fk/qmldir", "module Fk\nsingleton Lua 1.0 Lua.qml\n");
  writeFile(base + "/Fk/Lua.qml", fakeLua);
  writeFile(base + "/Probe.qml", probeQml);
  QQmlEngine engine;
  if (enabled) installIosMarkRefresh(&engine);
  engine.addImportPath(base);
  QQmlComponent component(&engine, QUrl::fromLocalFile(base + "/Probe.qml"));
  if (component.isError()) qWarning().noquote() << component.errorString();
  QObject *root = component.create();
  check(root, "create complete QML fixture");
  invoke(root, "setNumeric", 1);
  check(invoke(root, "numericText").toString() == "1", "first mark shown");
  invoke(root, "addMetadata");
  invoke(root, "setOther", 9);
  const int values[] = {2, 5, 4, 8};
  for (int value : values) {
    invoke(root, "setNumeric", value);
    check(invoke(root, "numericText").toString() == QString::number(enabled ? value : 1),
          "numeric delegate follows updates, baseline reproduces stale display");
    check(invoke(root, "otherText").toString() == "9", "other player unaffected");
    check(invoke(root, "metadata").toString() == "retained", "preserve mark metadata");
  }
  invoke(root, "setNumeric", 0);
  check(invoke(root, "numericText").toString() == "empty", "zero removes mark");
  invoke(root, "setNumeric", 3);
  check(invoke(root, "numericText").toString() == "3", "mark can reappear");
  if (enabled) {
    for (int n : {1, 4, 2, 0, 7}) {
      invoke(root, "setPicture", n);
      check(invoke(root, "pictureText").toString() == (n ? QString::number(n) : "empty"),
            "picture mark updates and removal");
    }
    for (int n : {1, 5, 2}) {
      invoke(root, "setCustom", n);
      check(invoke(root, "lastText").toString() == QString::number(n), "custom mark text updates");
      check(invoke(root, "customMetadata").toInt() == n, "custom popup metadata updates");
    }
    invoke(root, "setList", 1);
    check(invoke(root, "lastText").toString() == "slash", "list mark initial");
    invoke(root, "setList", 2);
    check(invoke(root, "lastText").toString() == "slash jink", "list mark updates");
  }
  check(readFile(util) == source, "server-managed source remains byte-for-byte unchanged");
  delete root;
  std::printf("PASS %s %s\n", enabled ? "fixed" : "baseline", qPrintable(relative));
}

int main(int argc, char **argv) {
  qputenv("QT_QPA_PLATFORM", "offscreen");
  QGuiApplication app(argc, argv);
  QCoreApplication::setApplicationName("FreeKillMarkRefreshTest");
  check(argc == 2, "usage: mark-refresh-test upstream-LtkLuaUtil.qml");
  const QByteArray source = readFile(QString::fromLocal8Bit(argv[1]));
  runCase(source, "builtin", false);
  runCase(source, "builtin", true);
  runCase(source, "packages/freekill-core", true);
  return 0;
}
