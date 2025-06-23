#!/bin/bash

set -euo pipefail
../../../external/bin/solc --optimize --overwrite --bin-runtime --abi interpreter.sol -o ../../../blobs
