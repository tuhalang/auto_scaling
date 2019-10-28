#!/bin/bash

maxRequest="50"
ports_start=("8080" "8081" "8082")
ports_shutdown=("8005" "8006" "8007")
ports_ajp=("9009" "9001" "9002")

cur_start=8081
cur_stop=8006
cur_apj=9010
ports=("8080")


numOfConnections
warFile=""
sourceFolder="/home/hungpv/Documents/test"
tarFile="apache-tomcat-9.0.27.tar.gz"
folderName="apache-tomcat-9.0.27"
targetFolder="/home/hungpv/Documents/test/virtual-"
numOfServerVirtual=2
currentPort=8082

getNumOfConnections(){
    for port in "${ports[@]}"; do
        num="$(curl --noproxy "*" --user admin:admin http://localhost:8080/manager/jmxproxy?qry=java.lang:type=Threading | grep '\bThreadCount\b')"
        s1=${num:13}
        numOfConnections+=$s1
    done
}

deploy(){
    # create new folder
    mkdir $targetFolder$numOfServerVirtual
    tar -xvzf $source$tarFile -C $targetFolder$numOfServerVirtual
    
    # change server port
    cd $targetFolder$numOfServerVirtual
    cd $folderName
    cd conf
    
    #change port shutdown
    xmlstarlet edit --inplace --update "Server[@port]/@port" --value "$cur_stop"  server.xml
    
    #change port start
    xmlstarlet edit --inplace --update "Server/Service/Connector[1][@port]/@port" --value "$cur_start"  server.xml
    
    #change port ajp
    xmlstarlet edit --inplace --update "Server/Service/Connector[2][@port]/@port" --value "$cur_apj"  server.xml

    ports+=($cur_start)
    echo "created new virtual server no. $numOfServerVirtual at port: $cur_start"
    
    # increment port
    cur_start=`expr $cur_start+1`
    cur_stop=`expr $cur_stop+1`
    cur_apj=`expr $cur_apj+1`
    
    # increment num of server virtual
    #numOfServerVirtual=`expr $numOfServerVirtual+1`
    # increment max request 
    #maxRequest=`expr $maxRequest+300`
    
    
    # deploy
    cd ../
    if [[ -e $warFile ]]; then
        cp $warFile webapps/
        ./bin/startup.sh
    else
        echo "$warFile not exist!"
    fi
}

deletePort(){
    for(( i=0; i < `expr ${#ports[@]} - 1`; i++ )); do
        newArr+=("${ports[i]}")
    done
    ports=("$(newArr[@])")
    unset newArr
}

undeploy(){
    if (( $numOfServerVirtual > 0 )); then
        cd $targetFolder$numOfServerVirtual
        cd $folderName
        ./bin/shutdown.sh
        rm -rf $targetFolder$numOfServerVirtual
        echo "deleted virtual server no. $numOfServerVirtual"
        # decrement port
        currentPort=`expr $currentPort-1`
        # decrement num of server virtual
        numOfServerVirtual=`expr $numOfServerVirtual-1`
        # decrement max request 
        #maxRequest=`expr $maxRequest-300`
        
        deletePort
    else
        echo "works"
    fi
}

while true; do
    numOfConnections=0
    getNumOfConnections
    numOfConnections=${numOfConnections:1}
    echo $numOfConnections
     if [[ $numOfConnections -gt $maxRequest ]]; then
         deploy
     #else
         #undeploy
     fi
        sleep 1
done
