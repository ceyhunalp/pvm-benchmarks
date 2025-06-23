#!/bin/bash

set -euo pipefail
../../../external/bin/solc --optimize --overwrite --bin-runtime --abi SHA1.sol -o ../../../blobs
