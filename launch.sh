#!/bin/bash

# Arguement commands are as followed: ami-d05e75b8 3 t2.micro sg-4a82be2d subnet-08d9f951 itmo444springVMWare mp1 mp1-elb mp1-launch-config mp1-auto-scaling-group mp1-scaleup-policy mp1-scaledown-policy

./cleanup.sh

declare -a instancecheck

mapfile -t instancecheck < <(aws ec2 run-instances --image-id $1 --count $2 --instance-type $3  --security-group-ids $4 --subnet-id $5 --key-name $6 --iam-instance-profile Name=$7 --associate-public-ip-address --user-data file://environment-setup/install-env.sh --output table | grep InstanceId | sed "s/|//g" | tr -d ' ' | sed "s/InstanceId//g")

echo ${instancecheck[@]}

aws ec2 wait instance-running --instance-ids ${instancecheck[@]}

echo "All instances are now running"

ELBURL=(`aws elb create-load-balancer --load-balancer-name $8 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --security-groups $4 --subnets $5 --output=text`);

echo -e "\nFinished launching ELB and waiting 25 seconds"

echo -e "\n"

for i in {0..25};do echo -ne '.';sleep 1;done

echo -e "\n"

aws elb register-instances-with-load-balancer --load-balancer-name $8 --instances ${instancecheck[@]}

aws elb configure-health-check --load-balancer-name $8 --health-check Target=HTTP:80/index.html,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=3

aws autoscaling create-launch-configuration --launch-configuration-name $9 --image-id $1 --key-name $6  --security-groups $4 --instance-type $3 --user-data file://environment-setup/install-env.sh --iam-instance-profile $7 --associate-public-ip-address

aws autoscaling create-auto-scaling-group --auto-scaling-group-name $10 --launch-configuration-name $9 --load-balancer-names $8  --health-check-type ELB --min-size 3 --max-size 6 --desired-capacity 3 --default-cooldown 600 --health-check-grace-period 120 --vpc-zone-identifier $5

PolicyARN1=(`aws autoscaling put-scaling-policy --policy-name $11 --auto-scaling-group-name $10 --scaling-adjustment 1 --adjustment-type ChangeInCapacity`);

PolicyARN2=(`aws autoscaling put-scaling-policy --policy-name $12 --auto-scaling-group-name $10 --scaling-adjustment -1 --adjustment-type ChangeInCapacity`);

aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 30 --comparison-operator GreaterThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$10" --evaluation-periods 2 --alarm-actions $PolicyARN1

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 --statistic Average --period 120 --threshold 10 --comparison-operator LessThanOrEqualToThreshold --dimensions "Name=AutoScalingGroupName,Value=$10" --evaluation-periods 2 --alarm-actions $PolicyARN2

mapfile -t dbInstanceARR < <(aws rds describe-db-instances --output json | grep "\"DBInstanceIdentifier" | sed "s/[\"\:\, ]//g" | sed "s/DBInstanceIdentifier//g")

      echo ${#dbInstanceARR[@]}
      LENGTH=${#dbInstanceARR[@]}
      for (( i=0; i<=${LENGTH}; i++));
      do
      if [[ ${dbInstanceARR[i]} == "mp1jphdb" ]] 
     then 
      echo "db exists"
     else
     aws rds create-db-instance --db-name mp1jphdb --db-instance-identifier mp1jphdb --db-instance-class db.t1.micro --engine MySQL --master-username jhedlund --master-user-password letmeinplease --allocated-storage 20 --vpc-security-group-ids $4 --db-subnet-group-name db-mp1-subnet
      fi  
     done


