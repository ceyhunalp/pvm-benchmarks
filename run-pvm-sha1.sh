#!/bin/bash

set -euo pipefail

echo "Running benchmark (PVM): SHA1"
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/guest-program.bin
