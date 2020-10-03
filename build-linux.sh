#!/usr/bin/env bash
set -xeuo pipefail
cd "$(dirname -- "$0")"

. versions



ROOTDIR="$(pwd)"
SHADOWDIR="$ROOTDIR/shadow"
DISTDIR="$ROOTDIR/dist"

if [[ $OSTYPE =~ ^darwin ]]
then
    OSX=1
else
    OSX=
fi

if [[ $OSX ]]
then
    NPROC="$(sysctl -n hw.activecpu)"
    export LLVM_INSTALL_DIR=/usr/local/opt/llvm
else
    NPROC="$(nproc)"
    export LLVM_INSTALL_DIR="/usr/lib/llvm-8"
fi

export QT_INSTALL_HEADERS="$DISTDIR/include"
export PATH="$DISTDIR/bin:$LLVM_INSTALL_DIR/bin${PATH:+:$PATH}"

if [[ $OSX ]]
then
    export DYLD_FALLBACK_LIBRARY_PATH="$DISTDIR/lib:$LLVM_INSTALL_DIR/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"
else
    export LD_LIBRARY_PATH="$DISTDIR/lib:$LLVM_INSTALL_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

export PKG_CONFIG_PATH="$DISTDIR/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="$ROOTDIR${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"


function doBootstrap {
    if [[ $OSX ]]
    then
        brew install pkg-config llvm xz zstd freetype > /dev/null
    else
        PACKAGES=(
            git
            build-essential
            python
            python3
            pkg-config
            libclang-8-dev
            cmake
            libfontconfig1-dev
            libwayland-dev
            libwayland-egl1-mesa
            libegl1-mesa-dev
            mesa-common-dev
            libssl-dev
            libxkbcommon-dev
            chrpath
        )

        INSTALLED="$(dpkg -s "${PACKAGES[@]}" 2>/dev/null | grep -Pio '^Status:.*\binstalled\b' | wc -l)" || true
        NEEDED=${#PACKAGES[@]}
        if [[ $INSTALLED != $NEEDED ]]
        then
            if [[ -t 1 ]]
            then
                YFLAG=""
            else
                YFLAG="-y"
                export DEBIAN_FRONTEND=noninteractive
            fi
            if [[ $EUID != 0 ]]
            then
                sudo apt update $YFLAG > /dev/null
                sudo apt install $YFLAG "${PACKAGES[@]}" > /dev/null
            else
                apt update $YFLAG > /dev/null
                apt install $YFLAG "${PACKAGES[@]}" > /dev/null
            fi
        fi
    fi
}



function doInit {
    PATCHFILES=(qtbase qtdeclarative)
    for PATCHFILENAME in "${PATCHFILES[@]}"
    do
        PATCHFILE="$ROOTDIR/$PATCHFILENAME.patch"
        if [[ ! -f $PATCHFILE ]]
        then
            echo "$PATCHFILE not found"
            exit -1
        fi
    done

    rm -rf qt5
    git clone https://code.qt.io/qt/qt5.git > /dev/null
    pushd qt5
        git checkout "$QT5_BUILD_QT" > /dev/null
        MODULE_SUBSET=qtbase,qtcharts,qtdeclarative,qtquickcontrols,qtquickcontrols2,qtgraphicaleffects,qttools,qttranslations
        ./init-repository --module-subset="$MODULE_SUBSET" > /dev/null
        for PATCHFILENAME in "${PATCHFILES[@]}"
        do
            pushd $PATCHFILENAME
                git apply "$ROOTDIR/$PATCHFILENAME.patch"
            popd
        done
    popd
}



function doConfigure {
    rm -rf "$SHADOWDIR"
    mkdir -p "$SHADOWDIR"
    pushd "$SHADOWDIR"

    ARGS=(
        -release
        -silent
        -prefix "$DISTDIR"
        -opensource
        -confirm-license
        -reduce-exports
        -make libs
        -make tools
        -no-glib
        -no-icu
        -opengl desktop
        -system-zlib \
        -qt-doubleconversion
        -qt-pcre
        -qt-harfbuzz
        -qt-libjpeg
        -qt-libpng
        -qt-sqlite
        -pkg-config
    )

    if [[ -z $OSX ]]
    then
        ARGS+=(
            -reduce-relocations
            -fontconfig
            -system-freetype
            -openssl
        )
    fi

    "$ROOTDIR/qt5/configure" "${ARGS[@]}"

    popd
}



function doBuild {
    pushd "$SHADOWDIR"
    make -j"$NPROC" &> /dev/null || make
    rm -rf "$DISTDIR"
    make install &> /dev/null || make install
    popd

    cat > "$DISTDIR/bin/qt.conf" << EOF
[Paths]
Prefix=..
EOF
}



function doDocs {
    pushd "$SHADOWDIR"
    make -j"$NPROC" docs &> /dev/null || make docs
    make install_qch_docs &> /dev/null || make install_qch_docs
    popd
}



function doLibs {
    #
    # QuaZip
    #
    rm -rf quazip
    git clone https://github.com/stachenov/quazip.git > /dev/null
    pushd quazip/quazip
        git checkout "$QT5_BUILD_QUAZIP" > /dev/null
        if [[ $OSX ]]
        then
            qmake PREFIX="$DISTDIR" QMAKE_LFLAGS+="-lz"
        else
            qmake PREFIX="$DISTDIR"
        fi
        make -j"$NPROC" &> /dev/null || make
        make install &> /dev/null || make install
    popd

    if [[ -z $OSX ]]
    then
        #
        # QtDBusExtended
        #
        #rm -rf qtdbusextended
        #git clone https://github.com/nemomobile/qtdbusextended.git > /dev/null
        #pushd qtdbusextended
        #    git checkout "$QT5_BUILD_QTDBUSEXTENDED" > /dev/null
        #    qmake
        #    make -j"$NPROC" &> /dev/null || make
        #    make install &> /dev/null || make install
        #popd

        #
        # QtMPRIS
        #
        rm -rf qtmpris
        git clone https://git.merproject.org/mer-core/qtmpris.git > /dev/null
        pushd qtmpris
            git checkout "$QT5_BUILD_QTMPRIS" > /dev/null
            qmake
            make -j"$NPROC" &> /dev/null || make
            make install &> /dev/null || make
        popd

        #
        # ECM
        #
        rm -rf extra-cmake-modules
        git clone https://github.com/KDE/extra-cmake-modules.git > /dev/null
        pushd extra-cmake-modules
            git checkout "$QT5_BUILD_KDECMAKEEXTRAMODULES" > /dev/null
            mkdir build
            cd build
            cmake -DCMAKE_INSTALL_PREFIX="$DISTDIR" ..
            make -j"$NPROC" &> /dev/null || make
            make install &> /dev/null || make install
        popd

        #
        # KSyntaxHighlighting
        #
        rm -rf syntax-highlighting
        git clone https://github.com/KDE/syntax-highlighting.git > /dev/null
        pushd syntax-highlighting
            git checkout "$QT5_BUILD_KSYNTAXHIGHLIGHTING" > /dev/null
            mkdir build
            cd build
            cmake -DCMAKE_INSTALL_PREFIX="$DISTDIR" .. > /dev/null
            make -j"$NPROC" &> /dev/null || make
            make install &> /dev/null || make install
        popd

        cp -a "$DISTDIR/lib/x86_64-linux-gnu/." "$DISTDIR/lib/"
        rm -rf "$DISTDIR/lib/x86_64-linux-gnu/"
    fi
}



function doQbs {
    rm -rf qbs
    git clone https://code.qt.io/qbs/qbs.git > /dev/null
    pushd qbs
        git checkout "$QT5_BUILD_QBS" > /dev/null
        git submodule update --init > /dev/null
        qmake
        make -j"$NPROC" &> /dev/null || make
        if [[ $OSX ]]
        then
            SED_INPLACE_OPTS=( -i "" )
        else
            SED_INPLACE_OPTS=( -i )
        fi
        find . -name 'Makefile*' -type f -exec sed "${SED_INPLACE_OPTS[@]}" -e 's/$(INSTALL_ROOT)\/usr\/local\//$(INSTALL_ROOT)\//g' {} +
        make install INSTALL_ROOT="$DISTDIR" &> /dev/null || make install INSTALL_ROOT="$DISTDIR"
        find . -name 'Makefile*' -type f -exec sed "${SED_INPLACE_OPTS[@]}" -e 's/$(INSTALL_ROOT)\/share\/doc\//$(INSTALL_ROOT)\/doc\//g' {} +
        make qch_docs install_inst_qch_docs INSTALL_ROOT="$DISTDIR" &> /dev/null || make qch_docs install_inst_qch_docs INSTALL_ROOT="$DISTDIR"
        if [[ $OSX ]]
        then
            install_name_tool -add_rpath "@executable_path/../../lib" "$DISTDIR/libexec/qbs/qbs_processlauncher"
        fi
        cat > "$DISTDIR/libexec/qbs/qt.conf" << EOF
[Paths]
Prefix=../..
EOF
    popd
}



function doPatch {
    ./relpc.py "$DISTDIR"

    if [[ -z $OSX ]]
    then
        find "$DISTDIR/lib" -iname '*.so*' -type f |
            while read LIBPATH
            do
                RELDIR="$(realpath --relative-to="$(dirname "$LIBPATH")" "$DISTDIR/lib")"
                if [[ $RELDIR == "." ]]
                then
                    NEW_RPATH='$ORIGIN'
                else
                    NEW_RPATH='$ORIGIN/'"$RELDIR"
                fi
                chrpath -r "$NEW_RPATH" "$LIBPATH" || true
            done
    fi
}



function doArchive {
    mkdir archive
    pushd archive
        mv ../dist qt5
        if [[ $OSX ]]
        then
            OS_NAME=osx
        else
            OS_NAME=linux
        fi
        ARCH="$(uname -m)"
        tar -cf - qt5 | xz -9e -c - > "qt5-$QT5_BUILD_QT-$OS_NAME-$ARCH.tar.xz"
    popd
}



case "${1:-}" in
    bootstrap) doBootstrap ;;
    init) doInit ;;
    configure) doConfigure ;;
    build) doBuild ;;
    docs) doDocs ;;
    libs) doLibs ;;
    qbs) doQbs ;;
    patch) doPatch ;;
    archive) doArchive ;;
    all)
        doBootstrap
        doInit
        doConfigure
        doBuild
        doDocs
        doLibs
        doQbs
        doPatch
        doArchive
        ;;
    *)
        echo "specify a valid task (bootstrap, init, configure, build, docs, libs, qbs, patch, archive, all) as a first argument"
        exit -1
        ;;
esac



echo "DONE!"
