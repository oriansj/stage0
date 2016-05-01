#!/bin/bash

# Build new
./hex2 < hex2_1.hex | sponge trial && ./exec_enable trial

# Test compile
./trial < foo > example2
readelf -a trial > summary2

# Check results
sha256sum example* summary*

