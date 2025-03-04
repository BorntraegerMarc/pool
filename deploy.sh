#!/bin/bash

docker build -t 861567669929.dkr.ecr.us-east-1.amazonaws.com/pool/ms1:latest ./microservice-1

docker push 861567669929.dkr.ecr.us-east-1.amazonaws.com/pool/ms1:latest
