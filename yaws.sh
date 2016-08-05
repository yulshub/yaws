#!/bin/bash
CONFIG_PATH="$HOME/.ysh"

PROFILE_LIST_FILE="$CONFIG_PATH/profiles"
INSTANCES_LIST_FILE="$CONFIG_PATH/instances"
INSTANCES_DETAILS_FILE="$CONFIG_PATH/instances_details"
INSTANCES_MENU_FILE="$CONFIG_PATH/instances_menu"
INSTANCES_PEM_FILES="$CONFIG_PATH/instances_pem"



bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

function usage
{
    echo "uso: ysh [-a] | [-d] | [-h]"
}

function init
{
#Si no existe el directorio de configuración lo creamos
if [ ! -d $CONFIG_PATH ];then mkdir -p $CONFIG_PATH; fi
#Perfiles de AWS
cat ~/.aws/credentials | grep "\\[" | grep -v default | sed "s/\[//g" | sed "s/\]//g"  | tr '[:lower:]' '[:upper:]' > $PROFILE_LIST_FILE
sort -f $PROFILE_LIST_FILE -o $PROFILE_LIST_FILE 
}

function printProfilesMENU
{
clear
echo ""
echo -e "${bold}AWS PROFILES MENU${reset}"
echo "---------------------------------------------------------------------------------------------------------------"
cat -n $PROFILE_LIST_FILE
echo "---------------------------------------------------------------------------------------------------------------"
echo -n "Elige un profile | ${bold}q${reset} para salir: "
}

function describeInstances
{

#jq -r '.Reservations[].Instances[].Tags[] | select(.Key=="Name") | .Value' TAG NAME

aws ec2 describe-instances --profile $1 > ${INSTANCES_DETAILS_FILE}_$1
cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r .Reservations[].Instances[].InstanceId > ${INSTANCES_LIST_FILE}_$1

rm -rf ${INSTANCES_MENU_FILE}_$1

while read line; do
    ID=$line
    DNS=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .PublicDnsName")
    if [ -z $DNS ]; then DNS="-"; fi
    PLATFORM=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .Platform")
    if [ "$PLATFORM" == "null" ]; then PLATFORM="linux"; fi
    STATUS=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .State.Name")
    INSTANCETYPE=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .InstanceType")
    PUBLICIP=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .PublicIpAddress")
    if [ "$PUBLICIP" == "null" ]; then PUBLICIP="-"; fi
    NAME=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | ." | jq -r ".Tags[] | select(.Key==\"Name\") | .Value")
    PEM=$(cat ${INSTANCES_DETAILS_FILE}_$1 | jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ID\") | .KeyName")
      
    echo -e "$ID;$NAME;$PLATFORM;$STATUS;$PEM.pem;$PUBLICIP;$DNS" >> ${INSTANCES_MENU_FILE}_$1
    #echo "$PEM" >> ${INSTANCES_MENU_FILE}_$1
done < ${INSTANCES_LIST_FILE}_$1
sort -k 2 -t';' -f ${INSTANCES_MENU_FILE}_$1 -o ${INSTANCES_MENU_FILE}_$1

}

function printEc2InstancesMENU 
{
clear
echo ""
echo -e "AWS INSTANCES MENU" 
echo -e "PROFILE SELECCIONADO: ${bold}$1${reset}"
echo "---------------------------------------------------------------------------------------------------------------------------------------"
cat -n ${INSTANCES_MENU_FILE}_$1 | column -t -s ";" | sed "s/running/${green}running${reset}/g" | sed "s/stopped/${red}stopped${reset}/g"
echo "---------------------------------------------------------------------------------------------------------------------------------------"
echo -n -e "Elige una instancia | ${bold}b${reset} para volver: "
}


#**********************************************************************************************************************************************************
function configurePEMS
{
PROFILE_SELECTED=$1 
PEM_FILE=$2
POSIBLES_PEM_FILE=${INSTANCES_PEM_FILES}_$PROFILE_SELECTED
find $HOME/. -name $PEM_FILE -type f > $POSIBLES_PEM_FILE
#-exec stat -s {} \; | awk -F ";" '{OFS = ";"; delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["Var"] } { print vars["file"],vars["st_mtime"] }')
cat $POSIBLES_PEM_FILE
}



function Ec2InstancesMenu
{
PROFILE_SELECTED=$1   
MENU_FILE=${INSTANCES_MENU_FILE}_$PROFILE_SELECTED
until [ "$selection" = "b" ]; do
     printEc2InstancesMENU $PROFILE_SELECTED
     read -n 2 selection
     echo ""
     case $selection in
         b ) break;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                echo "Seleccionada opcion : $selection"
                INSTANCE=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $1}')
                PEM=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $5}')
                echo "Instancia Seleccionada : $INSTANCE"
                echo "Buscando PEM : $PEM"
                configurePEMS $PROFILE_SELECTED $PEM
                read -n 1
             fi;;
     esac
done
}

#**********************************************************************************************************************************************************

function AWS
{
until [ "$selection" = "q" ]; do
     printProfilesMENU
     read -n 2 selection
     echo ""
     case $selection in
         q ) exit 0;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                PROFILE=$(sed "$selection!d" $PROFILE_LIST_FILE)
                echo "Perfil seleccionado : $PROFILE"
                describeInstances $PROFILE
                Ec2InstancesMenu $PROFILE
            fi;;
     esac
done
#cat $CONFIG_PATH/profiles 

}




#find $HOME/. -maxdepth 2 -type f -exec stat -s {} \; | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["Var"] } { print vars["st_mtime"] }'
##############################################################################################
#aws ec2 describe-images --filters Name=kernel-id,Values=aki-02486376 --owners amazon



init
if [ -z $1 ];then usage; exit 1 ; fi

while [ "$1" != "" ]; do
    case $1 in
        -a | --aws )            shift
                                AWS
                                ;;
        -d | --database )       DATABASE
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

