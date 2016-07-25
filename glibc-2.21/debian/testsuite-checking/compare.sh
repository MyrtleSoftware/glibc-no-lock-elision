#!/bin/bash

if [ $# -lt '2' -o $# -gt '3' ]; then
  echo -e "\nUsage: Compare a test-expected-* file and a test-results-* file."
  echo -e "$0 : < Expected testsuite results > < Testsuite results > < (optional) build directory >\n";
  exit 1
fi;

expected=$(tempfile)
results=$(tempfile)
grep -Ev '^ *$|^#' $1 | sort > $expected 
grep -Ev '^ *$|^#' $2 | sort > $results 

builddir=${3:-.}

echo "+--------------------------- BEGIN COMPARE ---------------------------+"
echo "Comparing against $1"
REGRESSIONS=$(diff -wBI '^#.*' $expected $results | sed -e '/^>/!d;s/^> //g')
PROGRESSIONS=$(diff -wBI '^#.*' $expected $results | sed -e '/^</!d;s/^< //g')
if [ -n "$REGRESSIONS" ] ; then
  echo "+---------------------------------------------------------------------+"
  echo "|     Encountered regressions that don't match expected failures:     |"
  echo "+---------------------------------------------------------------------+"
  echo "$REGRESSIONS"
  echo "+---------------------------------------------------------------------+"
  for test in $REGRESSIONS
  do
    echo TEST $test:
    cat $builddir/$test.out
  done
  rv=1
else
  echo "+---------------------------------------------------------------------+"
  echo "| Passed regression testing.  Give yourself a hearty pat on the back. |"
  echo "+---------------------------------------------------------------------+"
  for test in $(cat $results)
  do
    echo TEST $test:
    cat $builddir/$test.out
  done
  rv=0
fi

if [ -n "$PROGRESSIONS" ] ; then
  echo "+---------------------------------------------------------------------+"
  echo "|    Encountered progressions that don't match expected failures:     |"
  echo "+---------------------------------------------------------------------+"
  echo "$PROGRESSIONS"
fi
echo "+---------------------------- END COMPARE ----------------------------+"

rm -f $expected $results
# This would be a lovely place to exit 0 if you wanted to disable hard failures
#exit 0 # This line should be disabled after the Jessie release.
exit $rv
