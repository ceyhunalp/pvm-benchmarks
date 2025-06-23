#!/bin/bash

set -euo pipefail

mkdir -p external/bin

if [ ! -e external/bin/solc ]; then
    curl -O "https://binaries.soliditylang.org/linux-amd64/solc-linux-amd64-v0.8.30+commit.73712a01"
    mv solc-linux-amd64-v0.8.30+commit.73712a01 external/bin/solc
    chmod +x external/bin/solc
fi

if [ ! -e external/bin/evm ]; then
    curl -O "https://gethstore.blob.core.windows.net/builds/geth-alltools-linux-amd64-1.15.11-36b2371c.tar.gz"
    tar -xf geth-alltools-linux-amd64-1.15.11-36b2371c.tar.gz
    mv geth-alltools-linux-amd64-1.15.11-36b2371c/* external/bin/
    rmdir geth-alltools-linux-amd64-1.15.11-36b2371c
    rm geth-alltools-linux-amd64-1.15.11-36b2371c.tar.gz
fi

if [ ! -e external/bin/keccak-256sum ]; then
    cd external
    if [ ! -e libkeccak ]; then
        git clone "https://codeberg.org/maandree/libkeccak.git"
    fi
    if [ ! -e sha3sum ]; then
        git clone "https://codeberg.org/maandree/sha3sum.git"
    fi

    cd libkeccak
    git checkout 5c50a649600ccda1dd5f64225ed5cfcf5065f08b
    cd ..

    cd sha3sum
    git checkout d123948cd756f098b61f0c1229f998e7b322721f
    cd ..

    echo '#include "common.h"' > sha3sum/keccak-256sum.c
    echo 'KECCAK_MAIN(256)' >> sha3sum/keccak-256sum.c
    gcc --std=c99 -Ilibkeccak sha3sum/common.c sha3sum/keccak-256sum.c libkeccak/digest.c libkeccak/libkeccak_state_* libkeccak/spec/*.c libkeccak/util/*.c libkeccak/extra/*.c libkeccak/libkeccak_zerocopy_chunksize.c -o bin/keccak-256sum
    cd ..
fi

if [ ! -e external/bin/libevmone.so.0.15.0 ] || [ ! -e external/bin/evmc ]; then
    cd external
    if [ ! -e evmone ]; then
        git clone "https://github.com/ethereum/evmone.git"
    fi
    cd evmone
    git checkout eeb02e83bece5c3e99a804951001c8ed6bc64c43
    git submodule update --init
    cd evmc
    git checkout tools/evmc/main.cpp
    patch -p1 < ../../../evmc-patch.diff
    cd ..
    cd ../..
fi

if [ ! -e external/bin/libevmone.so.0.15.0 ]; then
    cd external/evmone
    mkdir -p build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release ..
    make -j
    cd ../..
    cp evmone/build/lib/libevmone.so.0.15.0 bin/
    cd ..
fi

if [ ! -e external/bin/evmc ]; then
    cd external/evmone/evmc
    mkdir -p build
    cd build
    cmake -DEVMC_TOOLS=1 -DCMAKE_BUILD_TYPE=Release ..
    make -j
    cd ../../..
    cp evmone/evmc/build/bin/evmc bin/
    cd ..
fi

echo "Setup done!"
