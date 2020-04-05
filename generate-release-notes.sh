#!/usr/bin/env bash
set -e
cd "$(dirname -- "$0")"

. versions

echo "
* [Qt](https://code.qt.io/cgit/qt/qt5.git/refs/): **$QT5_BUILD_QT** <sup>Linux, Windows, OSX</sup>

* [MSYS2 git hash](https://github.com/msys2/MINGW-packages/commits/master/mingw-w64-qt5): **$QT5_BUILD_MSYSGITHASH** <sup>Windows</sup>

* [Qbs](https://code.qt.io/cgit/qbs/qbs.git/refs/): **$QT5_BUILD_QBS** <sup>Linux, OSX</sup>

* [Quazip](https://github.com/stachenov/quazip/tags): **$QT5_BUILD_QUAZIP** <sup>Linux, OSX</sup>

* [Extended DBus for Qt](https://github.com/nemomobile/qtdbusextended/tags): **$QT5_BUILD_QTDBUSEXTENDED** <sup>Linux</sup>

* [Qt and QML MPRIS interface and adaptor](https://git.sailfishos.org/mer-core/qtmpris/-/tags): **$QT5_BUILD_QTMPRIS** <sup>Linux</sup>

* [KDE Extra CMake Modules](https://github.com/KDE/extra-cmake-modules/tags): **$QT5_BUILD_KDECMAKEEXTRAMODULES** <sup>Linux</sup>

* [KDE Syntax Highlighting](https://github.com/KDE/syntax-highlighting/tags): **$QT5_BUILD_KSYNTAXHIGHLIGHTING** <sup>Linux</sup>
"
