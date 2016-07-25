#!/bin/bash

if [ $# -ne '1' ]; then
  echo -e "\nUsage: Converts a log-test-* file into a test-results-* file."
  echo -e "$0 : < Input testsuite log file >\n";
  exit 1
fi;

echo '#'
echo '# Testsuite failures, someone should be working towards'
echo '# fixing these! They are listed here for the purpose of'
echo '# regression testing during builds.'
echo '#'
grep '^FAIL: ' $1 | sed -e's/FAIL: //' | sort -u
