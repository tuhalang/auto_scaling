#!/bin/bash


### arrays save information about ports of servers tomcat
PORTS_RUNNING=("8080")
PORTS_SHUTDOWN=("7070")
PORT_APJ=("9090")

### account tomcat has roles: manage-jmx, manage-gui
username="admin"
password="admin"

### initialize
NUM_OF_THREADS=0
NUM_OF_VIRTUAL_SERVER=0

MAX_THREADS=0
MAX_THREAD_PER_SERVER=10

NUM_OF_SERVERS_ARE_RUNNING=0
MIN_SERVERS=2


### next port if start-server
START=8081
SHUTDOWN=7071
APJ=9091

### folder of root server
FOLDER_NAME="apache-tomcat-9.0.27"
SOURCE_PATH="/home/tuhalang/Documents/"

### folder of virtual server
VIRTUAL_PATH="/home/tuhalang/Documents/virtual-"
rm -rf $VIRTUAL_PATH*

getNumOfThread(){
    NUM_OF_SERVERS_ARE_RUNNING=0
    NUM_OF_THREADS=0
    MAX_THREADS=0
    for port in "${PORTS_RUNNING[@]}"; do
        num=$(curl --noproxy "*" --user $username:$password http://localhost:$port/manager/jmxproxy?qry=java.lang:type=Threading | grep '\bThreadCount\b')
        num=$(sed -e 's/[[:space:]]*$//' <<<${num:13})
        if (( $num > 0 )); then
            NUM_OF_SERVERS_ARE_RUNNING=`expr $NUM_OF_SERVERS_ARE_RUNNING + 1`
            NUM_OF_THREADS=`expr $num + $NUM_OF_THREADS - 35`
            MAX_THREADS=`expr $MAX_THREAD_PER_SERVER + $MAX_THREADS`
        fi
    done
}

deploy(){
    # create new folder
    /bin/mkdir $VIRTUAL_PATH$NUM_OF_VIRTUAL_SERVER
    cp -a $SOURCE_PATH$FOLDER_NAME $VIRTUAL_PATH$NUM_OF_VIRTUAL_SERVER
    
    cd $VIRTUAL_PATH$NUM_OF_VIRTUAL_SERVER
    cd $FOLDER_NAME
    cd conf
    
    #change port shutdown
    xmlstarlet edit --inplace --update "Server[@port]/@port" --value "$SHUTDOWN"  server.xml
    
    #change port start
    xmlstarlet edit --inplace --update "Server/Service/Connector[1][@port]/@port" --value "$START"  server.xml
    
    #change port ajp
    xmlstarlet edit --inplace --update "Server/Service/Connector[2][@port]/@port" --value "$APJ"  server.xml

    PORTS_RUNNING+=($START)
    PORTS_SHUTDOWN+=($SHUTDOWN)
    PORT_APJ+=($APJ)
    echo "created new virtual server no. $NUM_OF_VIRTUAL_SERVER at port: $START"
    
    # increment port
    START=`expr $START + 1`
    SHUTDOWN=`expr $SHUTDOWN + 1`
    APJ=`expr $APJ + 1`
    
    # increment num of server virtual
    NUM_OF_VIRTUAL_SERVER=`expr $NUM_OF_VIRTUAL_SERVER + 1`
    # increment max request 
    MAX_THREADS=`expr $MAX_THREADS + $MAX_THREAD_PER_SERVER`
    
    # start server
    cd ../bin
    ./startup.sh
    sleep 1
}

deletePort(){
    for(( i=0; i < `expr ${#PORTS_RUNNING[@]} - 1`; i++ )); do
        newArr+=("${PORTS_RUNNING[i]}")
    done
    PORTS_RUNNING=("${newArr[@]}")
    unset newArr

    for(( i=0; i < `expr ${#PORTS_SHUTDOWN[@]} - 1`; i++ )); do
        newArr+=("${PORTS_SHUTDOWN[i]}")
    done
    PORTS_SHUTDOWN=("${newArr[@]}")
    unset newArr

    for(( i=0; i < `expr ${#PORT_APJ[@]} - 1`; i++ )); do
        newArr+=("${PORT_APJ[i]}")
    done
    PORT_APJ=("${newArr[@]}")
    unset newArr
}

undeploy(){
    if (( $NUM_OF_SERVERS_ARE_RUNNING > $MIN_SERVERS )); then
               
        # decrement port
        START=`expr $START - 1`
        SHUTDOWN=`expr $SHUTDOWN - 1`
        APJ=`expr $APJ - 1`

        # decrement num of server virtual
        NUM_OF_VIRTUAL_SERVER=`expr $NUM_OF_VIRTUAL_SERVER - 1`
        # decrement max request 
        MAX_THREADS=`expr $MAX_THREADS - $MAX_THREAD_PER_SERVER`

        deletePort

        cd $VIRTUAL_PATH$NUM_OF_VIRTUAL_SERVER
        cd $FOLDER_NAME
        ./bin/shutdown.sh
        rm -rf $VIRTUAL_PATH$NUM_OF_VIRTUAL_SERVER

         echo "deleted virtual server no. $NUM_OF_VIRTUAL_SERVER at port: $START"
    fi
}


while true; do
    getNumOfThread
    echo "Current threads: $NUM_OF_THREADS"
    echo "Max threads: $MAX_THREADS"
    echo "Servers are running: $NUM_OF_SERVERS_ARE_RUNNING"
    if [[ $NUM_OF_THREADS -ge $MAX_THREADS ]] || (( $NUM_OF_SERVERS_ARE_RUNNING < $MIN_SERVERS)); then
        deploy
    elif (( $NUM_OF_THREADS < ($MAX_THREADS - $MAX_THREAD_PER_SERVER - $MAX_THREAD_PER_SERVER) )); then
        undeploy
    fi
        sleep 1
done
