// SPDX-License-Identifier: GPL-3.0-or-later
#include "runtime.h"
#include <QCryptographicHash>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QMutex>
#include <QMutexLocker>
#include <QObject>
#include <QQmlAbstractUrlInterceptor>
#include <QQmlEngine>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

namespace {
// Qt 6.8 does not notify bindings when a JS object's fields inside list<var>
// change. Replace the list element instead, preserving all existing metadata.
const QByteArray oldMarkUpdate = R"FK(      elem.value = textValue;
      elem.origValue = value;
      elem.qml = qmlComponentSpec;
      elem.desc = desc;)FK";
const QByteArray newMarkUpdate = R"FK(      // FreeKill iOS mark-refresh-v1: notify list<var> delegates on Qt 6.8.
      marks.splice(elemIdx, 1, Object.assign({}, elem, {
        value: textValue, origValue: value, qml: qmlComponentSpec, desc,
      }));)FK";

class MarkRefreshInterceptor final : public QObject, public QQmlAbstractUrlInterceptor {
public:
  explicit MarkRefreshInterceptor(QQmlEngine *engine)
      : QObject(engine), cacheRoot(QStandardPaths::writableLocation(
            QStandardPaths::CacheLocation) + "/freekill-ios-mark-refresh-v1") {}

  QUrl intercept(const QUrl &url, DataType type) override {
    if (type != QmlFile || !url.isLocalFile()
        || !url.path().endsWith("/LunarLtk/LtkLuaUtil.qml"))
      return url;
    QMutexLocker lock(&mutex);
    if (resolved.contains(url)) return resolved.value(url);
    QFile input(url.toLocalFile());
    if (!input.open(QIODevice::ReadOnly)) return url;
    QByteArray contents = input.readAll();
    contents.replace("\r\n", "\n");
    if (contents.contains("mark-refresh-v1")) return url;
    if (contents.count(oldMarkUpdate) != 1) {
      qWarning() << "iOS mark refresh: unrecognized QML implementation" << url;
      return url;
    }
    contents.replace(oldMarkUpdate, newMarkUpdate);
    const QByteArray digest = QCryptographicHash::hash(contents,
        QCryptographicHash::Sha256).toHex();
    if (!QDir().mkpath(cacheRoot)) return url;
    const QString path = cacheRoot + "/" + QString::fromLatin1(digest) + ".qml";
    QFile cached(path);
    const bool current = cached.open(QIODevice::ReadOnly) && cached.readAll() == contents;
    cached.close();
    if (!current) {
      QSaveFile output(path);
      if (!output.open(QIODevice::WriteOnly)
          || output.write(contents) != contents.size() || !output.commit()) {
        qWarning() << "iOS mark refresh: cannot save compatibility QML";
        return url;
      }
    }
    const QUrl replacement = QUrl::fromLocalFile(path);
    resolved.insert(url, replacement);
    qInfo() << "iOS mark refresh enabled for" << url;
    return replacement;
  }

private:
  const QString cacheRoot;
  QMutex mutex;
  QHash<QUrl, QUrl> resolved;
};
} // namespace

void installIosMarkRefresh(QQmlEngine *engine) {
  // The engine's QObject children outlive its QML loader teardown. The source
  // file stays untouched, so server package checks/updates retain clean Git data.
  engine->addUrlInterceptor(new MarkRefreshInterceptor(engine));
}
