#!/bin/bash

set -euo pipefail

echo "Running benchmark (EVM, geth): SHA1"
external/bin/evm run --statdump --gas 1000000000000 --codefile blobs/SHA1.bin-runtime --inputfile blobs/evm-input.txt
