#!/bin/bash
flags=(-O2 -g0 -fno-exceptions -fvisibility=hidden)
cycc -i2.0 -oMobileSafety.dylib -- "${flags[@]}" -dynamiclib MobileSafety.mm \
    -framework CoreFoundation -framework Foundation -framework UIKit \
    -L. -lsubstrate -lobjc
