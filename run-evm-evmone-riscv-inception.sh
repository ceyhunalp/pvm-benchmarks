#!/bin/bash

set -euo pipefail

echo "Running benchmark (EVM, evmone): RISC-V inception"
time external/bin/evmc --vm external/bin/libevmone.so.0.15.0 run --gas 1000000000000 @blobs/Interpreter.bin-runtime --input @blobs/evm-input.txt
