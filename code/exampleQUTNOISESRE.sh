#!/bin/bash -eu

OUTPUT=../QUT-NOISE-SRE/NIST2008/

EVALNOISES="CAFE-CAFE HOME-LIVINGB STREET-KG CAR-WINUPB REVERB-CARPARK"
TRAINPOSTFIX='-1'
TESTPOSTFIX='-2'
SNRS="-10 -5 0 5 10 15"

TRAINLIST=NIST2008.train.short2.list
TESTLIST=NIST2008.test.short3.list

SPLIT=40

for noise in $EVALNOISES; do
    # training files
    qxargs -N TR_$noise -f $TRAINLIST -o logs -I {} -m matlab -s $SPLIT -S -l MATLAB=1,walltime=3:59:59 -- \
	matlab -r "\"batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels'," \
	"'../QUT-NOISE/impulses', '/work/SAIVT/NIST2008/', gettxt('{}'), 'activlev', " \
	"'"$OUTPUT"', 8e3, '"${noise}${TRAINPOSTFIX}"', ["$SNRS"]); exit\"" &
    # testing files
    qxargs -N TE_$noise -f $TESTLIST -o logs -I {} -m matlab -s $SPLIT -S -l MATLAB=1,walltime=3:59:59 -- \
	matlab -r "\"batchaddnoisetospeech('../QUT-NOISE', '../QUT-NOISE/labels'," \
	"'../QUT-NOISE/impulses', '/work/SAIVT/NIST2008/', gettxt('{}'), 'activlev', " \
	"'"$OUTPUT"', 8e3, '"${noise}${TESTPOSTFIX}"', ["$SNRS"]); exit\"" &
done

wait