#!/bin/bash

set -euo pipefail

echo "Running benchmark (EVM, geth): RISC-V inception"
external/bin/evm run --statdump --gas 1000000000000 --codefile blobs/Interpreter.bin-runtime --inputfile blobs/evm-input.txt
