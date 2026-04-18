#!/bin/bash
#
# Example:
#         ./scripts/darwin-build.sh
#
set -eo pipefail

STAGE_ROOT="${STAGE_ROOT:-/opt/stage}"
BUILD_ROOT="${BUILD_ROOT:-/opt/build}"

JSON_C_VERSION="${JSON_C_VERSION:-0.18}"
MBEDTLS_VERSION="${MBEDTLS_VERSION:-3.6.6}"
LIBUV_VERSION="${LIBUV_VERSION:-1.52.1}"
LIBWEBSOCKETS_VERSION="${LIBWEBSOCKETS_VERSION:-4.5.8}"

build_json-c() {
    echo "=== Building json-c-${JSON_C_VERSION} ..."
    curl -fSsLo- "https://s3.amazonaws.com/json-c_releases/releases/json-c-${JSON_C_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/json-c-${JSON_C_VERSION}"
        rm -rf build && mkdir -p build && cd build
        cmake \
            -DCMAKE_BUILD_TYPE=RELEASE \
            -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_TESTING=OFF \
            -DDISABLE_THREAD_LOCAL_STORAGE=ON \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            ..
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_mbedtls() {
    echo "=== Building mbedtls-${MBEDTLS_VERSION} ..."
    curl -fSsLo- "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-${MBEDTLS_VERSION}/mbedtls-${MBEDTLS_VERSION}.tar.bz2" | tar xj -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/mbedtls-${MBEDTLS_VERSION}"
        rm -rf build && mkdir -p build && cd build
        cmake \
            -DCMAKE_BUILD_TYPE=RELEASE \
            -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
            -DENABLE_TESTING=OFF \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            ..
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_libuv() {
    echo "=== Building libuv-${LIBUV_VERSION} ..."
    curl -fSsLo- "https://dist.libuv.org/dist/v${LIBUV_VERSION}/libuv-v${LIBUV_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/libuv-v${LIBUV_VERSION}"
        ./autogen.sh
        ./configure --disable-shared --enable-static --prefix="${STAGE_DIR}"
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_libwebsockets() {
    echo "=== Building libwebsockets-${LIBWEBSOCKETS_VERSION} ..."
    curl -fSsLo- "https://github.com/warmcat/libwebsockets/archive/v${LIBWEBSOCKETS_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/libwebsockets-${LIBWEBSOCKETS_VERSION}"
        sed -i '' 's/ websockets_shared//g' cmake/libwebsockets-config.cmake.in
        rm -rf build && mkdir -p build && cd build
        cmake \
            -DCMAKE_BUILD_TYPE=RELEASE \
            -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
            -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
            -DLWS_WITHOUT_TESTAPPS=ON \
            -DLWS_WITH_MBEDTLS=ON \
            -DLWS_WITH_LIBUV=ON \
            -DLWS_STATIC_PIC=ON \
            -DLWS_WITH_SHARED=OFF \
            -DLWS_UNIX_SOCK=ON \
            -DLWS_IPV6=ON \
            -DLWS_ROLE_RAW_FILE=OFF \
            -DLWS_WITH_HTTP2=ON \
            -DLWS_WITH_HTTP_BASIC_AUTH=OFF \
            -DLWS_WITH_HTTP_STREAM_COMPRESSION=ON \
            -DLWS_WITH_UDP=OFF \
            -DLWS_WITHOUT_CLIENT=ON \
            -DLWS_WITHOUT_EXTENSIONS=OFF \
            -DLWS_WITH_LEJP=OFF \
            -DLWS_WITH_LEJP_CONF=OFF \
            -DLWS_WITH_LWSAC=OFF \
            -DLWS_WITH_SEQUENCER=OFF \
            -DLWS_WITH_UPNG=OFF \
            -DLWS_WITH_JPEG=OFF \
            -DLWS_WITH_DLO=OFF \
            -DLWS_WITH_SYS_STATE=OFF \
            -DLWS_WITH_SYS_SMD=OFF \
            -DLWS_WITH_SECURE_STREAMS=OFF \
            -DLWS_CTEST_INTERNET_AVAILABLE=OFF \
            -DCMAKE_PREFIX_PATH="${STAGE_DIR}" \
            -DLIBUV_INCLUDE_DIRS="${STAGE_DIR}/include" \
            -DLIBUV_LIBRARIES="${STAGE_DIR}/lib/libuv.a" \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            ..
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_ttyd() {
    echo "=== Building ttyd ..."
    rm -rf build && mkdir -p build && cd build
    cmake \
        -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
        -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
        -DCMAKE_C_FLAGS="-Os -ffunction-sections -fdata-sections -fno-unwind-tables -fno-asynchronous-unwind-tables -flto" \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DCMAKE_PREFIX_PATH="${STAGE_DIR}" \
        ..
        make
        strip ttyd
        make install
}

build() {
    STAGE_DIR="${STAGE_ROOT}"
    BUILD_DIR="${BUILD_ROOT}"

    rm -rf "${STAGE_DIR}" "${BUILD_DIR}"
    mkdir -p "${STAGE_DIR}" "${BUILD_DIR}"
    export PKG_CONFIG_PATH="${STAGE_DIR}/lib/pkgconfig"

    build_json-c
    build_libuv
    build_mbedtls
    build_libwebsockets
    build_ttyd
}

build
