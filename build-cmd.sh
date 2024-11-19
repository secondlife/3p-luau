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

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]] ; then
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

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

mkdir -p "$stage/include/luau"
mkdir -p "$stage/lib/release"

pushd "$top/luau"
    pushd "VM/include"
    cp -v lua.h luaconf.h lualib.h "$stage/include/luau/"
    popd
    pushd "Compiler/include"
    cp -v luacode.h "$stage/include/luau/"
    popd

    # Don't litter the source directory with build artifacts
    mkdir -p ../build
    cd ../build
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            set -o igncr
            opts="$(replace_switch /Zi /Z7 $LL_BUILD_RELEASE) /EHsc"
            plainopts="$(remove_switch /GR $(remove_cxxstd $opts))"

            cmake -G "Ninja" -DCMAKE_BUILD_TYPE="Release" \
                  -DCMAKE_INSTALL_PREFIX="$(cygpath -m "$stage")" \
                  -DCMAKE_C_FLAGS="$(remove_cxxstd $opts)" \
                  -DCMAKE_CXX_FLAGS="$opts" \
                  ../luau
            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ./Luau.UnitTest.exe
                ./Luau.Conformance.exe
                ./Luau.UnitTest.exe --fflags=true
                ./Luau.Conformance.exe --fflags=true
                ./Luau.Conformance.exe -O2
                ./Luau.Conformance.exe -O2 --fflags=true
                ./Luau.Conformance.exe --codegen
                ./Luau.Conformance.exe --codegen --fflags=true
                ./Luau.Conformance.exe --codegen -O2
                ./Luau.Conformance.exe --codegen -O2 --fflags=true
                ./luau ../luau/tests/conformance/assert.lua
                ./luau-analyze ../luau/tests/conformance/assert.lua
                ./luau-compile ../luau/tests/conformance/assert.lua
            fi

            mkdir -p "$stage/bin"

            cp -v "Luau.Ast.lib" "$stage/lib/release/"
            cp -v "Luau.CodeGen.lib" "$stage/lib/release/"
            cp -v "Luau.Compiler.lib" "$stage/lib/release/"
            cp -v "Luau.Config.lib" "$stage/lib/release/"
            cp -v "Luau.VM.lib" "$stage/lib/release/"

            cp -v luau.exe "$stage/bin/"
        ;;
        darwin*)
            export MACOSX_DEPLOYMENT_TARGET="$LL_BUILD_DARWIN_DEPLOY_TARGET"

            for arch in x86_64 arm64 ; do
                ARCH_ARGS="-arch $arch"
                opts="${TARGET_OPTS:-$ARCH_ARGS $LL_BUILD_RELEASE}"
                cc_opts="$(remove_cxxstd $opts)"
                ld_opts="$ARCH_ARGS"

                mkdir -p "build_$arch"
                pushd "build_$arch"
                    CFLAGS="$cc_opts" \
                    CXXFLAGS="$opts" \
                    LDFLAGS="$ld_opts" \
                    cmake -G Ninja -DCMAKE_BUILD_TYPE="Release" \
                        -DCMAKE_INSTALL_PREFIX:STRING="${stage}" \
                        -DCMAKE_CXX_FLAGS="$opts" \
                        -DCMAKE_C_FLAGS="$cc_opts" \
                        -DCMAKE_OSX_ARCHITECTURES="$arch" \
                        -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} \
                        ../../luau
                    cmake --build . --config Release

                    # conditionally run unit tests
                    if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                        ./Luau.UnitTest
                        ./Luau.Conformance
                        ./Luau.UnitTest --fflags=true
                        ./Luau.Conformance --fflags=true
                        ./Luau.Conformance -O2
                        ./Luau.Conformance -O2 --fflags=true
                        ./Luau.Conformance --codegen
                        ./Luau.Conformance --codegen --fflags=true
                        ./Luau.Conformance --codegen -O2
                        ./Luau.Conformance --codegen -O2 --fflags=true
                        ./luau ../../luau/tests/conformance/assert.lua
                        ./luau-analyze ../../luau/tests/conformance/assert.lua
                        ./luau-compile ../../luau/tests/conformance/assert.lua
                    fi

                    mkdir -p "$stage/lib/release/$arch"
                    cp -v "libLuau.Ast.a" "$stage/lib/release/$arch"
                    cp -v "libLuau.CodeGen.a" "$stage/lib/release/$arch"
                    cp -v "libLuau.Compiler.a" "$stage/lib/release/$arch"
                    cp -v "libLuau.Config.a" "$stage/lib/release/$arch"
                    cp -v "libLuau.VM.a" "$stage/lib/release/$arch"
                popd
            done

            # Create universal libraries
            lipo -create -output ${stage}/lib/release/libLuau.Ast.a ${stage}/lib/release/x86_64/libLuau.Ast.a ${stage}/lib/release/arm64/libLuau.Ast.a
            lipo -create -output ${stage}/lib/release/libLuau.CodeGen.a ${stage}/lib/release/x86_64/libLuau.CodeGen.a ${stage}/lib/release/arm64/libLuau.CodeGen.a
            lipo -create -output ${stage}/lib/release/libLuau.Compiler.a ${stage}/lib/release/x86_64/libLuau.Compiler.a ${stage}/lib/release/arm64/libLuau.Compiler.a
            lipo -create -output ${stage}/lib/release/libLuau.Config.a ${stage}/lib/release/x86_64/libLuau.Config.a ${stage}/lib/release/arm64/libLuau.Config.a
            lipo -create -output ${stage}/lib/release/libLuau.VM.a ${stage}/lib/release/x86_64/libLuau.VM.a ${stage}/lib/release/arm64/libLuau.VM.a
        ;;
        linux64*)
            cmake -G Ninja -DCMAKE_BUILD_TYPE="Release" \
                  -DCMAKE_INSTALL_PREFIX:STRING="${stage}" \
                  -DCMAKE_CXX_FLAGS="$LL_BUILD_RELEASE" \
                  -DCMAKE_C_FLAGS="$(remove_cxxstd $LL_BUILD_RELEASE)" \
                  ../luau
            cmake --build . --config Release

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                ./Luau.UnitTest
                ./Luau.Conformance
                ./Luau.UnitTest --fflags=true
                ./Luau.Conformance --fflags=true
                ./Luau.Conformance -O2
                ./Luau.Conformance -O2 --fflags=true
                ./Luau.Conformance --codegen
                ./Luau.Conformance --codegen --fflags=true
                ./Luau.Conformance --codegen -O2
                ./Luau.Conformance --codegen -O2 --fflags=true
                ./luau ../luau/tests/conformance/assert.lua
                ./luau-analyze ../luau/tests/conformance/assert.lua
                ./luau-compile ../luau/tests/conformance/assert.lua
            fi

            cp -v "libLuau.Ast.a" "$stage/lib/release"
            cp -v "libLuau.CodeGen.a" "$stage/lib/release"
            cp -v "libLuau.Compiler.a" "$stage/lib/release"
            cp -v "libLuau.Config.a" "$stage/lib/release"
            cp -v "libLuau.VM.a" "$stage/lib/release"
        ;;
    esac
popd

mkdir -p "$stage/LICENSES"
cp "$top/LICENSE" "$stage/LICENSES/luau.txt"
