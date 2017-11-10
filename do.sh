#!/bin/bash
mkdir _
cp percona-build.sh _
cd _
./percona-build.sh -s 2.1.6 -p 5.6.17-66.0 -d 5.6.17-66.0 -o ubuntu
