#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

top="$(pwd)"
stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

LUAU_VERSION="0.609"

pushd "$top/luau"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            set -o igncr
            opts="$LL_BUILD_RELEASE /EHsc"
            cmake -G "$AUTOBUILD_WIN_CMAKE_GEN" -A "$AUTOBUILD_WIN_VSPLATFORM" \
                  -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$stage")" \
                  -DCMAKE_C_FLAGS="$opts" \
                  -DCMAKE_CXX_FLAGS="$opts" \
                  .
            cmake --build . -- /p:Configuration=Release
            cmake --build . --target Luau.Repl.CLI -- /p:Configuration=Release

            mkdir -p "$stage/include/luau"
            mkdir -p "$stage/lib/release"
            mkdir -p "$stage/bin"
            pushd "$src/VM/include"
            cp -v lua.h luaconf.h lualib.h "$stage/include/luau/"
            popd
            pushd "$src/Compile/include"
            cp -v luacode.h "$stage/include/lua/"
            popd
            cp -v "Release/isocline.lib" "$stage/lib/release/"
            cp -v "Release/Luau.Ast.lib" "$stage/lib/release/"
            cp -v "Release/Luau.CodeGen.lib" "$stage/lib/release/"
            cp -v "Release/Luau.Compiler.lib" "$stage/lib/release/"
            cp -v "Release/Luau.Config.lib" "$stage/lib/release/"

            cp -v Release/luau{,c}.exe "$stage/bin/"
        ;;
    esac
popd

echo "$LUAU_VERSION.$build" > "$stage/VERSION.txt"
mkdir -p "$stage/LICENSES"
cp "$top/LICENSE" "$stage/LICENSES/luau.txt"
