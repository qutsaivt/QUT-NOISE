#!/bin/bash -eu
for split in t1 t2 t3 t4; do
    awk '$2=="timit.'$split'" {print $1}' QUT-NOISE-TIMIT.splits \
	| grep -f /dev/stdin QUT-NOISE-TIMIT.wavlist \
	> QUT-NOISE-TIMIT.$split.wavlist
    echo "Created QUT-NOISE-TIMIT.$split.wavlist"
done