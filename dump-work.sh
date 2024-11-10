#!/bin/bash
set -o errexit
source util.sh

createDump "dumps/work"
createWorkDiff
