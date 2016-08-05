#!/bin/bash
VERSION="b0.0.14"

CONFIG_PATH="$HOME/.ysh"

PROFILE_LIST_FILE="$CONFIG_PATH/profiles"
EC2_INSTANCES_LIST_FILE="$CONFIG_PATH/ec2_instances"
EC2_INSTANCES_DETAILS_FILE="$CONFIG_PATH/ec2_instances_details"
EC2_INSTANCES_MENU_FILE="$CONFIG_PATH/Eec2_instances_menu"
#
EC2_INSTANCES_PEM_FILES="$CONFIG_PATH/ec2_instances_pem"
#
EC2_INSTANCES_MANAGE_MENU_FILE="$CONFIG_PATH/Eec2_instances_manage_menu"


bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

#********************************************************************************************************************************************************** 
# INIT COMMON
#**********************************************************************************************************************************************************

function init
{
#Modo debug
rm -rf $CONFIG_PATH 
#Si no existe el directorio de configuración lo creamos
if [ ! -d $CONFIG_PATH ];then mkdir -p $CONFIG_PATH; fi
}

function usage
{
    echo "uso: yaws [[-e|--ec2]|[-d|--database]|[-h|--help]]"
}

function lines
{
MAX_LINES=$1
FROM_LINES=$2
if [ -z "$2" ];then FROM_LINES=1; fi
for (( x=$FROM_LINES; x<=$MAX_LINES; x++ )) do echo -e "\n"; done

}

#********************************************************************************************************************************************************** 
# PROFILES
#**********************************************************************************************************************************************************

function createProfilesMenu
{
#Perfiles de AWS
cat ~/.aws/credentials | grep "\\[" | grep -v default | sed "s/\[//g" | sed "s/\]//g"  | tr '[:lower:]' '[:upper:]' > $PROFILE_LIST_FILE
if [ ! -s ${PROFILE_LIST_FILE} ]; then
    echo "No profile found in ~/.aws/credentials"
    exit 1
fi
sort -f $PROFILE_LIST_FILE -o $PROFILE_LIST_FILE 
}


function printProfilesMENU
{
clear
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e " ${bold}AWS PROFILES MENU : ${red}EC2 Mode${reset}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
cat -n $PROFILE_LIST_FILE
#lines 40 35
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n "Choose profile | ${bold}${green}r${reset}efresh | ${bold}${red}q${reset}uit: "
}

function profilesMenu
{
MODE=$1
createProfilesMenu
until [ "$selection" = "q" ]; do
     printProfilesMENU
     read -r -n 2 selection
     echo ""
     case $selection in
         q ) exit 0;;
         r ) createProfilesMenu;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                PROFILE=$(sed "$selection!d" $PROFILE_LIST_FILE)
                echo "Perfil seleccionado : $PROFILE"
                case $MODE in
                    EC2 ) EC2InstancesMenu $PROFILE;;
                    DATABASE ) continue;;
                esac
            fi;;
     esac
done
}

#********************************************************************************************************************************************************** 
# EC2
#**********************************************************************************************************************************************************
function createEC2instancesDetailFile
{
PROFILE_SELECTED=$1
DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED
aws ec2 describe-instances --profile $PROFILE_SELECTED > $DETAILS_FILE
}

function createEC2instancesListFile
{
PROFILE_SELECTED=$1
DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED
INSTANCES_FILE=${EC2_INSTANCES_LIST_FILE}_$PROFILE_SELECTED
cat $DETAILS_FILE | jq -r .Reservations[].Instances[].InstanceId > $INSTANCES_FILE
}

function getPropertyEC2Instance
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
PROPERTY_SEARCHED=$3

DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED

RETURN_VALUE=$(cat $DETAILS_FILE | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$INSTANCE_SELECTED\") | .$PROPERTY_SEARCHED")
if [ -z $RETURN_VALUE ];then RETURN_VALUE="-"; fi
echo $RETURN_VALUE

}

function getKeyValuePropertyEC2Instance
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
ARRAY_SEARCHED=$3
KEY_SEARCHED=$4
KEY_VALUE_SEARCHED=$5
VALUE_SEARCHED=$6

DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED

RETURN_VALUE=$(cat $DETAILS_FILE | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$INSTANCE_SELECTED\") | ." | jq -r ".${ARRAY_SEARCHED}[] | select(.$KEY_SEARCHED==\"$KEY_VALUE_SEARCHED\") | .$VALUE_SEARCHED")
if [ -z "$RETURN_VALUE" ];then 
    RETURN_VALUE="-" 
fi
echo $RETURN_VALUE

}


function createEC2InstancesMENU
{
PROFILE_SELECTED=$1 

MENU_FILE=${EC2_INSTANCES_MENU_FILE}_$PROFILE_SELECTED
INSTANCES_FILE=${EC2_INSTANCES_LIST_FILE}_$PROFILE_SELECTED
DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED

createEC2instancesDetailFile $PROFILE_SELECTED

if [ ! -f $DETAILS_FILE ]; then return 0; fi

createEC2instancesListFile $PROFILE_SELECTED

rm -rf $MENU_FILE

while read INSTANCE_SELECTED; do
    DNS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PublicDnsName")
    PLATFORM=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "Platform");if [ "$PLATFORM" == "null" ]; then PLATFORM="linux"; fi
    STATUS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "State.Name")
    INSTANCETYPE=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "InstanceType")
    PUBLICIP=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PublicIpAddress")
    NAME=$(getKeyValuePropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "Tags" "Key" "Name" "Value")
    PEM=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "KeyName")

    echo -e "$INSTANCE_SELECTED;$NAME;$PLATFORM;$STATUS;$PEM.pem;$INSTANCETYPE;$DNS" >> $MENU_FILE

done < $INSTANCES_FILE
sort -k 2 -t';' -f $MENU_FILE -o $MENU_FILE

}

function printEC2InstancesMENU 
{
PROFILE_SELECTED=$1 
MENU_FILE=${EC2_INSTANCES_MENU_FILE}_$PROFILE_SELECTED
clear
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "AWS EC2 INSTANCES MENU" 
echo -e "SELECTED PROFILE : ${bold}$PROFILE_SELECTED${reset}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
if [ ! -f $MENU_FILE ]; then 
    echo -e "No info to show. Check your credentials for profile ${bold}$PROFILE_SELECTED${reset}"
else
    cat -n $MENU_FILE | column -t -s ";" | sed "s/running/${green}running${reset}/g" | sed "s/stopped/${red}stopped${reset}/g"
fi
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n -e "Choose EC2 instance | ${bold}${green}r${reset}efresh | ${bold}b${reset}ack | ${bold}${red}q${reset}uit: "
}


function EC2InstancesMenu
{
PROFILE_SELECTED=$1   
createEC2InstancesMENU $PROFILE_SELECTED
until [ "$selection" = "b" ]; do
     printEC2InstancesMENU $PROFILE_SELECTED
     read -r -n 2 selection
     case $selection in
         b ) break;;
         q ) exit 0;;
         r ) createEC2InstancesMENU $PROFILE_SELECTED;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                #echo "Seleccionada opcion : $selection"
                INSTANCE_SELECTED=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $1}')
                PEM=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $5}')
                #echo "Instancia Seleccionada : $INSTANCE_SELECTED"
                #echo "Buscando PEM : $PEM"
                createPEMFILE $PROFILE_SELECTED $INSTANCE_SELECTED $PEM
                EC2InstancesManageMenu $PROFILE_SELECTED $INSTANCE_SELECTED
                selection=""
             fi;;
     esac
done
}

#**********************************************************************************************************************************************************

function createPEMFILE
{
PROFILE_SELECTED=$1 
INSTANCE_SELECTED=$2
PEM_SEARCHED=$3

PEM_FILE=${EC2_INSTANCES_PEM_FILES}_${PROFILE_SELECTED}_${INSTANCE_SELECTED}
find $HOME/. -name $PEM_SEARCHED -type f > $PEM_FILE

PEM_FOUNDED=$(cat $PEM_FILE | wc -l)
#-exec stat -s {} \; | awk -F ";" '{OFS = ";"; delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["Var"] } { print vars["file"],vars["st_mtime"] }')
#echo "$PEM_FOUNDED pem(s) encontrado(s)"
#echo "ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress')"

#cat $PEM_FILE
}



#********************************************************************************************************************************************************** 
# EC2 Manage Instance
#**********************************************************************************************************************************************************

function printEC2ManageInstanceMENU 
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
INSTANCE_NAME=$(getKeyValuePropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'Tags' 'Key' 'Name' 'Value')
MENU_FILE=${EC2_INSTANCES_MENU_FILE}_$PROFILE_SELECTED
clear
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "AWS EC2 INSTANCES MENU" 
echo -e "SELECTED PROFILE : ${bold}$PROFILE_SELECTED${reset}"
echo -e "SELECTED INSTANCE : ${bold}$INSTANCE_SELECTED / $INSTANCE_NAME${reset}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "1. Connect via SSH"
echo -e "2. Copy File(s) ${bold}FROM${reset} $PROFILE_SELECTED -> $INSTANCE_NAME"
echo -e "3. Copy File(s) ${bold}TO${reset} $PROFILE_SELECTED -> $INSTANCE_NAME"
echo -e "4. Execute command ${bold}IN${reset} $PROFILE_SELECTED -> $INSTANCE_NAME"
echo -e "5. View log(s) ${bold}FROM${reset} $PROFILE_SELECTED -> $INSTANCE_NAME"
echo -e "6. View Proces(s) running ${bold}IN${reset} $PROFILE_SELECTED -> $INSTANCE_NAME"
echo -e "7. Network tools"
echo -e "8. Monitoring tools"
echo -e "9. Manage Tools"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n -e "Choose Option | ${bold}${green}r${reset}efresh | ${bold}b${reset}ack | ${bold}${red}q${reset}uit: "
}

function EC2InstancesManageMenu
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2   
#createEC2ManageInstanceMENU $PROFILE_SELECTED $INSTANCE_SELECTED
until [ "$selection" = "b" ]; do
     printEC2ManageInstanceMENU $PROFILE_SELECTED $INSTANCE_SELECTED
     read -n 1 selection
     echo ""
     case $selection in
         b ) break;;
         q ) exit 0;;
         r ) continue;; #createEC2ManageInstanceMENU $PROFILE_SELECTED $INSTANCE_SELECTED;;
         1 ) ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress');;   
         2 ) read -er -p"Files in $PROFILE_SELECTED -> $INSTANCE_NAME : " SOURCE_FILES
             read -er -p"Target path : "  TARGET_FILES
             scp -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress'):$SOURCE_FILES $TARGET_FILES
             read -n 1;;     
         3 ) read -er -p"Local Files : " SOURCE_FILES
             read -er -p"Target path in $PROFILE_SELECTED -> $INSTANCE_NAME : "  TARGET_FILES
             scp -i $(head -1 $PEM_FILE) $SOURCE_FILES ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress'):$TARGET_FILES
             read -n 1;;     
         4 ) read -er -p"Type command : " COMMAND
             ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') $COMMAND
             read -n 1;;              
         5 ) read -er -p"Type absolute path to log : " LOG_PATH
             ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') less $LOG_PATH
             read -n 1;;  
         6 ) read -er -p"Write filter, empty to all : " GREP_FILTER
             ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') ps -fea | grep "$GREP_FILTER"
             read -n 1;;
         7 ) echo "Network tools";;   
         8 ) echo "Monitoring tools";;   
         9 ) echo "Manage tools";;   
         * ) continue;;
     esac

done
}



#********************************************************************************************************************************************************** 
# MAIN
#**********************************************************************************************************************************************************

init
if [ -z $1 ];then usage; exit 1 ; fi

while [ "$1" != "" ]; do
    case $1 in
        -e | --ec2 )            shift
                                profilesMenu EC2
                                ;;
        -d | --database )       profilesMenu DATABASE
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

