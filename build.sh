#!/bin/sh -x
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export VICE=${USERPROFILE}/Downloads/GTK3VICE-3.8-win64/bin
mkdir build 2>/dev/null
${ACME}/acme -f cbm -o build/ch64edit.prg -l build/ch64edit.lbl -r build/ch64edit.lst ch64edit.asm \
&& ${VICE}/c1541 ch64edit.d64 -attach ch64edit.d64 8 -delete ch64edit.prg -write build/ch64edit.prg \
&& rm d64_files/* \
&& ${VICE}/c1541 ch64edit.d64 -attach ch64edit.d64 8 -cd d64_files -extract \
&& ls -l d64_files \
&& ${VICE}/x64sc -moncommands build/ch64edit.lbl -autostart ch64edit.d64 >/dev/null 2>&1 &
