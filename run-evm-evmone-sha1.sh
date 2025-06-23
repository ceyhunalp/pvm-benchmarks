#!/bin/bash

set -euo pipefail

echo "Running benchmark (EVM, evmone): SHA1"
time external/bin/evmc --vm external/bin/libevmone.so.0.15.0 run --gas 1000000000000 @blobs/SHA1.bin-runtime --input @blobs/evm-input.txt
