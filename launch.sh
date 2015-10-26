#!/bin/bash

aws ec2 run-instances --image-id $1 --count $2 --instance-type $3  --security-group-ids $4 --subnet-id $5 --key-name $6