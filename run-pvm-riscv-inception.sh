#!/bin/bash

set -euo pipefail

echo "Running benchmark (PVM): RISC-V inception"
cargo run --release -p pvm-host blobs/riscv-inception.polkavm blobs/guest-program.bin
