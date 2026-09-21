#!/bin/sh

set -u
export D=$1
R=$2
export X=$(ruby --version | cut -d ' ' -f 2)
bundle config set without publish
bundle install

cd $R
(
    echo "Built on $D Ruby $X on $(date '+%Y-%m-%d %H:%M')"
    cat _logs/info.txt
    NO_COLOR=1 rake test
    echo "Test exit code: $?"
) 2>&1 | tee -a "$R/_logs/$D-$X.log"
rake clean
