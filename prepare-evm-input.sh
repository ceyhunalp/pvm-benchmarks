#!/bin/bash

set -euo pipefail

echo -n "0x" > blobs/evm-input.txt
echo -n "run(bytes)" | external/bin/keccak-256sum | cut -c1-8 | tr -d '\n' >> blobs/evm-input.txt
echo -n "0000000000000000000000000000000000000000000000000000000000000020" >> blobs/evm-input.txt
ruby ./blob-to-hex.rb blobs/guest-program.bin >> blobs/evm-input.txt
