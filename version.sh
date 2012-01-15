#!/bin/bash
git describe --always --tags --dirty="+" --match="v*" | sed -e 's@-\([^-]*\)-\([^-]*\)$@+\1.\2@;s@^v@@'
