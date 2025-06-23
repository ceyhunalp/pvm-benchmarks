#!/bin/bash

set -euo pipefail

PROFILE=release
cargo build --profile $PROFILE --target="$(polkatool get-target-json-path)" -Z build-std=core,alloc
polkatool link --strip --run-only-if-newer --min-stack-size 16384 --output ../../../blobs/riscv-inception.polkavm ../../../target/riscv64emac-unknown-none-polkavm/$PROFILE/riscv-inception
stat ../../../blobs/riscv-inception.polkavm
