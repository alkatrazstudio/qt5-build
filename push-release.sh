#!/usr/bin/env bash
set -e
cd "$(dirname -- "$0")"

. versions

VER="$QT5_BUILD_QT"
SUBVER="$(git tag | sort -Vr | grep -Po "${VER//./\\.}-\K\d+" | head -1)"
if [[ -z $SUBVER ]]
then
    SUBVER=0
else
    SUBVER=$(($SUBVER + 1))
fi
NEW_TAG="$VER-$SUBVER"

git tag -s -a "$NEW_TAG" -m "$NEW_TAG"
git push --follow-tags
