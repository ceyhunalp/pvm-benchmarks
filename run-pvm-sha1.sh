#!/bin/bash

set -euo pipefail

echo "Running benchmark (PVM): SHA1"
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/sha1-1k.input
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/sha1-10k.input
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/sha1-100k.input
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/sha1-1m.input
cargo run --release -p pvm-host blobs/sha1-demo.polkavm blobs/sha1-10m.input
