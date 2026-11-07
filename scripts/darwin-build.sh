#!/bin/bash
set -eo pipefail

STAGE_ROOT="${STAGE_ROOT:-/opt/stage}"
BUILD_ROOT="${BUILD_ROOT:-/opt/build}"

JSON_C_VERSION="${JSON_C_VERSION:-0.19}"
OPENSSL_VERSION="${OPENSSL_VERSION:-4.0.3}"
LIBUV_VERSION="${LIBUV_VERSION:-1.53.0}"
LIBWEBSOCKETS_VERSION="${LIBWEBSOCKETS_VERSION:-5.1.0}"

build_json-c() {
    echo "=== Building json-c-${JSON_C_VERSION} ..."
    curl -fSsLo- "https://s3.amazonaws.com/json-c_releases/releases/json-c-${JSON_C_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/json-c-${JSON_C_VERSION}"
        rm -rf build && mkdir -p build && cd build
        cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_BUILD_TYPE=RELEASE \
            -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
            -DBUILD_APPS=0 \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_TESTING=OFF \
            -DDISABLE_THREAD_LOCAL_STORAGE=ON \
            ..
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_openssl() {
    echo "=== Building openssl-${OPENSSL_VERSION} ..."
    curl -sLo- "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" | tar xz -C "${BUILD_DIR}"
    pushd "${BUILD_DIR}/openssl-${OPENSSL_VERSION}"
        ## configure without -flto to avoid "error: field 'ctx' has incomplete type"
        env CFLAGS="${CFLAGS//-flto}" \
            ./Configure enable-ec_nistp_64_gcc_128 \
                no-shared no-ech \
                no-apps no-docs no-tests no-tls1 no-tls1_1 \
                no-err no-filenames no-legacy \
                no-async no-autoerrinit no-cmp no-cms no-comp no-ct no-dgram no-dso no-gost no-http no-module no-nextprotoneg \
                no-posix-io no-rdrand no-rfc3779 no-sm2-precomp no-srp no-srtp no-ssl-trace no-ts no-uplink no-integrity-only-ciphers \
                no-aria no-bf no-blake2 no-camellia no-cast no-cmac \
                no-des no-dh no-dsa \
                no-ec2m no-hmac-drbg-kdf no-idea no-kbkdf no-krb5kdf \
                no-md4 no-mdc2 \
                no-ml-dsa \
                no-ocb no-pvkkdf no-rc2 no-rc4 no-rmd160 no-scrypt \
                no-seed no-siphash no-siv no-slh-dsa no-sm2 no-sm3 no-sm4 no-snmpkdf no-srtpkdf no-sshkdf no-sskdf \
                no-x942kdf no-x963kdf no-whirlpool \
                -DOPENSSL_SMALL_FOOTPRINT --prefix="${STAGE_DIR}" --libdir=lib \
        && make -j"$(sysctl -n hw.ncpu)" all > /dev/null && make install_sw
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
        cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_BUILD_TYPE=RELEASE \
            -DCMAKE_INSTALL_PREFIX="${STAGE_DIR}" \
            -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
            -DLWS_WITHOUT_TESTAPPS=ON \
            -DLWS_WITH_SSL=ON \
            -DLWS_WITH_LIBUV=ON \
            -DLWS_STATIC_PIC=ON \
            -DLWS_WITH_SHARED=OFF \
            -DLWS_UNIX_SOCK=ON \
            -DLWS_IPV6=ON \
            -DLWS_ROLE_RAW_FILE=OFF \
            -DLWS_WITH_HTTP2=ON \
            -DLWS_WITH_HTTP_BASIC_AUTH=OFF \
            -DLWS_WITH_HTTP_STREAM_COMPRESSION=0 \
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
            -DCMAKE_PREFIX_PATH="${STAGE_DIR}" \
            -DLIBUV_INCLUDE_DIRS="${STAGE_DIR}/include" -DLIBUV_LIBRARIES="${STAGE_DIR}/lib/libuv.a" \
            -DLWS_OPENSSL_INCLUDE_DIRS="${STAGE_DIR}/include" -DLWS_OPENSSL_LIBRARIES="${STAGE_DIR}/lib/libssl.a;${STAGE_DIR}/lib/libcrypto.a" \
            -DLWS_WITH_HTTP_UNCOMMON_HEADERS=1 \
            -DLWS_WITH_GENCRYPTO=1 \
            -DLWS_WITH_CUSTOM_HEADERS=1 \
            -DLWS_WITH_FILE_OPS=1 \
            -DLWS_WITH_SYS_ASYNC_DNS=0 \
            -DLWS_WITH_SYS_INFO=0 \
            -DLWS_WITH_HTTP_DIGEST_AUTH=0 \
            -DLWS_WITH_GZINFLATE=0 \
            -DLWS_WITH_SVG=0 \
            -DLWS_WITH_GIF=0 \
            -DLWS_WITH_LHP=0 \
            -DLWS_WITH_HL=0 \
            -DLWS_WITH_MD=0 \
            -DLWS_WITH_JSONRPC=0 \
            -DLWS_WITH_STUB=0 \
            -DLWS_WITH_DIR=0 \
            -DLWS_WITH_MINIMAL_EXAMPLES=0 \
            -DLWS_WITH_CONMON=0 \
            -DLWS_WITH_WOL=0 \
            -DLWS_WITH_CACHE_NSCOOKIEJAR=0 \
            -DLWS_WITH_CACHE_BLOB=0 \
            ..
        make -j"$(sysctl -n hw.ncpu)" install
    popd
}

build_ttyd() {
    echo "=== Building ttyd ..."
    rm -rf build && mkdir -p build && cd build
    cmake \
        -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
        -DCMAKE_EXE_LINKER_FLAGS="-flto -dead_strip" \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DCMAKE_PREFIX_PATH="${STAGE_DIR}" \
        ..
        make
        strip ttyd
}

build() {
    STAGE_DIR="${STAGE_ROOT}"
    BUILD_DIR="${BUILD_ROOT}"

    rm -rf "${STAGE_DIR}" "${BUILD_DIR}"
    mkdir -p "${STAGE_DIR}" "${BUILD_DIR}"
    export PKG_CONFIG_PATH="${STAGE_DIR}/lib/pkgconfig"
    export CFLAGS='-flto -D_FORTIFY_SOURCE=3 -ftrivial-auto-var-init=zero -fstack-protector-strong -O2 -fomit-frame-pointer -ffunction-sections -fdata-sections -fvisibility=hidden -fno-unwind-tables -fno-asynchronous-unwind-tables'

    build_json-c
    build_libuv
    build_openssl
    build_libwebsockets
    build_ttyd
}

build
