#!/bin/bash

set -euo pipefail

home=$(pwd)

echo "Running benchmark (Native): SHA1"
cd benchmarks/sha1/rust;
./build.sh
outfile="${home}/logs/sha1-native.log"
cargo run --release > "$outfile"
