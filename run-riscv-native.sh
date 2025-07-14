#!/bin/bash

set -euo pipefail

mkdir -p logs

counts=("10" "100" "1k" "10k" "100k" "1m" "10m" "100m" "full")
home=$(pwd)

echo "Running benchmark (Native): RISC-V"
cd benchmarks/riscv-inception/rust/src;
for c in "${counts[@]}"; do
	patch="../../../../patches/patch-${c}.patch"
	outfile="${home}/logs/riscv-native-${c}.log"
	patch -p0 < $patch
	cargo run --release > "$outfile"
	git stash push -- .
done

