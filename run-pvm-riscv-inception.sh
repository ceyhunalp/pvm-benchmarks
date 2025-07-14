#!/bin/bash

set -euo pipefail

counts=("10" "100" "1k" "10k" "100k" "1m" "10m" "100m" "full")
home=$(pwd)

echo "Running benchmark (PVM): RISC-V inception"
for c in "${counts[@]}"; do
	cd benchmarks/riscv-inception/rust/src
	outfile="${home}/logs/riscv-pvm-${c}.log"
	patch="../../../../patches/patch-${c}.patch"
	patch -p0 < $patch
	cd ../
	./build.sh
	cd $home
	cargo run --release -p pvm-host blobs/riscv-inception.polkavm blobs/guest-program.bin > "$outfile"
	git stash push -- benchmarks/
done
