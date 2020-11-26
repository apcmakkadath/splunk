#!/bin/bash

##### Written by Aravind Chaliyadath - apcmakkadath@gmail.com #####
##### Custom script to install and configure splunk forwarder #####
##### Hardcoded 1 deployment server, 2 indexer server #####

##### value initialization
flag=1
logfile=install.log
exec &> >(tee  $logfile)

##### write date timestamp
date >> $logfile
echo "##########################################"

##### root user check
if [ "$EUID" -ne 0 ]
  then echo Please run ascript as root
  flag=0
  exit
fi

##### filename check
files=$(ls -1 | grep ^splunkforwarder-*.*tgz$)
filecount=$(ls -1 | grep ^splunkforwarder-*.*tgz$ | wc -l)

if [ $filecount -eq 0  ]
        then echo $filecount splunk forwarder installation tar files found
        flag=0
	exit
fi

if [ $filecount -gt 1  ]
        then echo $filecount installation tar files found
        echo $files
        echo Please keep only the latest splunkforwarder tar file
	flag=0
	exit
fi

if [ $filecount -eq 1  ]
        then echo Installation file found: $files
	read -p "Deployment server port [8089]: " mgmtport
	mgmtport=${mgmtport:-8089}
	read -p "Indexer port [9997]: " indexerport
	indexerport=${indexerport:-9997}
	read -p "Deployment server server [192.168.1.10]: " deploymentserver01
	deploymentserver01=${deploymentserver01:-192.168.1.10}
	read -p "Indexer 1 [192.168.1.11]: " indexer01
	indexer01=${indexer01:-192.168.1.11}
	read -p "Indexer 2 [192.168.1.12]: " indexer02
	indexer02=${indexer02:-192.168.1.12}
        read -p 'Start installation(y/n): ' ready
fi

##### remote port connectivity result
us01=$(timeout 1 bash -c '</dev/tcp/'$deploymentserver01'/'$mgmtport' && echo 1 || echo 0' || echo 2)
ix01=$(timeout 1 bash -c '</dev/tcp/'$indexer01'/'$indexerport' && echo 1 || echo 0' || echo 2)
ix02=$(timeout 1 bash -c '</dev/tcp/'$indexer02'/'$indexerport' && echo 1 || echo 0' || echo 2)

##### port connectivity
if [ "$us01" -ne 1  ]
  then echo Utility server connectivity failed
  flag=0
fi

if [ "$ix01" -ne 1  ]
  then echo Indexer01 connectivity failed
  flag=0
fi

if [ "$ix02" -ne 1  ]
  then echo Indexer02 connectivity failed
  flag=0
fi

##### readyness check
ready=$(echo "$ready" | tr '[:upper:]' '[:lower:]')
if [ "$ready" != "y" ] && [ "$ready" != "yes" ]
	then flag=0
fi


##### splunk forwarder installation
if [ $flag -eq 1 ] 
	then echo Installation started successfully
	echo ======================================
	tar xvf $files -C /opt
	groupadd splunk
        useradd -g splunk splunk -d /opt/splunkforwarder
	chown -R splunk:splunk /opt/splunkforwarder
	su splunk -c '/opt/splunkforwarder/bin/splunk start --accept-license --answer-yes --no-prompt --seed-passwd changeme'
	/opt/splunkforwarder/bin/splunk enable boot-start -user splunk
	su splunk -c '/opt/splunkforwarder/bin/splunk set deploy-poll '$deploymentserver01':'$mgmtport' -auth admin:changeme'
	su splunk -c '/opt/splunkforwarder/bin/splunk restart'
	echo Installation completed successfully
	echo ======================
	else echo Installation cancelled
	echo ===========================
fi
