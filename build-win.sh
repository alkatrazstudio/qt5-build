#!/usr/bin/env bash
set -ex
cd "$(dirname -- "$(readlink -f -- "$0")")"

. versions


if [[ $MSYSTEM == MINGW32 ]]
then
    PKG_ARCH=i686
else
    PKG_ARCH=x86_64
fi

pacman --noconfirm -Su
pacman --noconfirm --needed -S git patch dos2unix "mingw-w64-$PKG_ARCH-toolchain" > /dev/null

rm -rf MINGW-packages
git clone https://github.com/msys2/MINGW-packages.git > /dev/null
pushd MINGW-packages
    git checkout "$QT5_BUILD_MSYSGITHASH" > /dev/null
    git apply --ignore-space-change --ignore-whitespace ../mingw-packages.patch
    dos2unix mingw-w64-qt5/PKGBUILD
popd

SRC_DIR="/home/a"
mv MINGW-packages/mingw-w64-qt5 "$SRC_DIR"

cp qtbase.patch qtdeclarative.patch "$SRC_DIR/"

cd "$SRC_DIR"
makepkg --skipinteg --syncdeps --noconfirm

echo "ALL DONE!"
