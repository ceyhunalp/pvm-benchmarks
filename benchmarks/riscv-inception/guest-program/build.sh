#!/bin/bash

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

export RUSTC_BOOTSTRAP=1
echo $PWD

PROFILE=release-small

RUSTFLAGS="-C target-feature=+unaligned-scalar-mem -C link-arg=--entry=entry_point -C link-arg=-T -C link-arg=$PWD/memory.ld -C link-arg=--icf=all -C relocation-model=static" \
cargo build --target=riscv32i-unknown-none-elf --profile $PROFILE -Z unstable-options -Z build-std=core,alloc
riscv32-elf-objcopy -O binary --only-section=.text ../../../target/riscv32i-unknown-none-elf/$PROFILE/guest-program ../../../blobs/guest-program.bin
riscv32-elf-objdump -j .bss -h ../../../target/riscv32i-unknown-none-elf/$PROFILE/guest-program | grep .bss | sed -E "s/  +/ /g" | cut -d " " -f 4 | fold -w2 | tac | tr -d '\n' | xxd -p -r >> ../../../blobs/guest-program.bin
stat ../../../blobs/guest-program.bin
