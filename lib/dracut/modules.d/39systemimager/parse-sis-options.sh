#!/bin/bash

type getarg >/dev/null 2>&1 || . /lib/dracut-lib.sh
type shellout >/dev/null 2>&1 || . /lib/systemimager-lib.sh

# Save cmdline SIS relevant parameters
variableize_kernel_append_parameters

# Init /run/systemimager directory
mkdir -p /run/systemimager
