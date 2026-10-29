// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QString>
bool prepareIosData(QString *error);
class QQmlEngine;
void installIosMarkRefresh(QQmlEngine *engine);
