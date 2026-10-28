// SPDX-License-Identifier: GPL-3.0-or-later
#import <Foundation/Foundation.h>
#include "runtime.h"
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>

// Called BEFORE installing FreeKill's log handler or opening relative files.
bool prepareIosData(QString *error) {
  @autoreleasepool {
    const QString bundled = QString::fromNSString([[NSBundle mainBundle] resourcePath])
        + "/fk-data";
    const QString writable = QString::fromNSString(NSHomeDirectory())
        + "/Documents/FreeKill";
    auto fail = [&](const QString &message) { *error = message; return false; };
    if (!QDir(bundled).exists() || !QDir().mkpath(writable))
      return fail("Missing bundled resources or cannot create Documents/FreeKill");

    QFile version(bundled + "/ios-source-revision");
    if (!version.open(QIODevice::ReadOnly))
      return fail("Cannot read bundled source revision");
    const auto revision = version.readAll().trimmed();
    if (revision.isEmpty()) return fail("Empty bundled source revision");
    QFile installed(writable + "/.ios-installed-revision");
    const bool current = installed.open(QIODevice::ReadOnly)
        && installed.readAll().trimmed() == revision;
    installed.close();
    if (!current) {
      QDirIterator it(bundled, QDir::Files | QDir::NoDotAndDotDot,
                      QDirIterator::Subdirectories);
      while (it.hasNext()) {
        const QString src = it.next();
        const QString relative = QDir(bundled).relativeFilePath(src);
        const QString dest = writable + "/" + relative;
        if (it.fileInfo().isSymLink()) return fail("Unexpected resource symlink");
        // Server-managed packages and user-installed extensions survive updates.
        if (relative.startsWith("packages/") && QFileInfo::exists(dest)) continue;
        if (!QDir().mkpath(QFileInfo(dest).absolutePath()))
          return fail("Cannot create resource directory: " + relative);
        QFile input(src);
        QSaveFile output(dest);
        if (!input.open(QIODevice::ReadOnly) || !output.open(QIODevice::WriteOnly))
          return fail("Cannot open resource: " + relative);
        while (!input.atEnd()) {
          const auto block = input.read(1024 * 1024);
          if ((block.isEmpty() && input.error() != QFile::NoError)
              || output.write(block) != block.size())
            return fail("Cannot copy resource: " + relative);
        }
        if (!output.commit()) return fail("Cannot save resource: " + relative);
      }
      QSaveFile marker(writable + "/.ios-installed-revision");
      if (!marker.open(QIODevice::WriteOnly)
          || marker.write(revision) != revision.size() || !marker.commit())
        return fail("Cannot save resource revision");
    }
    if (!QDir::setCurrent(writable)) return fail("Cannot enter writable directory");
    return true;
  }
}
