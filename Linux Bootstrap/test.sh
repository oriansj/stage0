#!/bin/bash

# Build new
./bin/hex < hex0.hex |
sponge bin/trial && ./bin/exec_enable bin/trial

# Test compile
./bin/trial < hex0.hex |
sponge tmp/foo

# Check results
sha256sum bin/trial tmp/foo
