#!/bin/bash  -

if [ $# -lt 1 ]; then
echo "error, no arguments."
echo "usage:"
echo "./$0 'aws_id1 aws_id2 aws_id3 aws_idn'  'private_ip1 private_ip2 private_ip3 private_ipn' 'instance_zone'"
exit 1
fi
echo $2
IFS=' '
instance_ids=($1)
instance_private_ip=($2)
instance_zone=($3)

#Log_in AWS
/usr/bin/expect <<-EOF
spawn aws configure
expect "AWS Access Key ID"
send "XXX\r"
expect "AWS Secret Access Key"
send "XXX\r"
expect "Default region name"
send "${instance_zone}\r"
expect "Default output format"
send "\r"
expect eof
EOF


#start aws servers

for var in ${instance_ids[@]}; do
   aws ec2 start-instances --instance-ids "$var"  --region ${instance_zone}
done


cd ~
declare -i num=${#instance_ids[@]}
declare -i sum=`expr $num-1`
#get Ygomi_1_cloud status, when running exit
for i in {1..30}
   do
     for ((i=0; i<=sum; i++))
       do
         eval instance_id=${instance_ids[${i}]}
         aws ec2 describe-instances --instance-ids "${instance_id}"  > aws_server_${i}_status_file.txt
         eval tmp=aws_server_${i}_status_file.txt
         status_tmp=`cat "${tmp}"  | grep "\"Name\":" | awk -F':' '{print $2}' | awk -F'"' '{print $2}'`
         eval aws_server_status_${i}=${status_tmp}
     done
     
     flag=0
     for ((i=0; i<=sum; i++))
        do
          eval status=\$aws_server_status_${i}
          echo ${status}
          if [ "${status}" != "running" ]; then 
            flag=1
          else
            sleep 2
          fi
     done

      if [ "$flag" = "0" ]; then
          break
      else
          continue
      fi   
done

#If flag=1, turns some of the servers are not running
if [ "$flag" = "1" ]; then
  echo "Some of the aws servers are not starting yet"
  exit
else
  echo "All the servers are running now!!!"
fi

#Get aws servers' public ip address and public dns       
for ((i=0;i<=sum;i++))
  do
    eval tmp_file=aws_server_${i}_status_file.txt
    private_ip=`cat "${tmp_file}" | grep "\"PrivateIpAddress\": \"[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\"" | head -1 |awk  '{print $2}'|awk -F'"' '{print $2}'`
    echo $private_ip
    echo ${instance_private_ip[${i}]}
    if [ "$private_ip" = "${instance_private_ip[${i}]}" ]; then
         echo "Get public ip and dns...."
         cat "${tmp_file}" | grep "\"PublicIpAddress\": \"[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\"" | head -1 |awk  '{print $2}'|awk -F'"' '{print $2}' > ${i}_public_ip.txt
         cat "${tmp_file}" | grep "\"PublicDnsName\":" | head -1 | awk -F ":" '{print $2}' | awk -F "\"" '{print $2}' >  ${i}_public_dns.txt
    else
         continue
    fi
done 

for ((i=0;i<=sum;i++))
  do 
    rm aws_server_${i}_status_file.txt
done
