#!/bin/sh -x
export ACME=${USERPROFILE}/Downloads/acme0.97win/acme
export VICE=${USERPROFILE}/Downloads/GTK3VICE-3.8-win64/bin
mkdir build 2>/dev/null
${ACME}/acme -f cbm -o build/ch20edit.prg -l build/ch20edit.lbl ch20edit.asm \
&& ${VICE}/c1541 ch20edit.d64 -attach ch20edit.d64 8 -delete ch20edit.prg -write build/ch20edit.prg \
&& rm d64_files/* \
&& ${VICE}/c1541 ch20edit.d64 -attach ch20edit.d64 8 -cd d64_files -extract \
&& ls -l d64_files \
&& ${VICE}/xvic -moncommands build/ch20edit.lbl -autostart ch20edit.d64 >/dev/null 2>&1 &
