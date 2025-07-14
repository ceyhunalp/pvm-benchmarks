#!/bin/bash

set -euo pipefail

mkdir -p ./logs

counts=("1k" "10k" "100k" "1m" "10m")

echo "Running benchmark (PVM): SHA1"
for c in "${counts[@]}"; do
	input="./blobs/sha1-${c}.input"
	output="./logs/sha1-pvm-${c}.log"
	cargo run --release -p pvm-host blobs/sha1-demo.polkavm $input > "$output"
done
