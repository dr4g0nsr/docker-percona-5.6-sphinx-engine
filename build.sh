#!/bin/bash

#docker images -q --filter dangling=true | xargs docker rmi
docker build -t dr4g0nsr/percona-5.6-sphinx .
