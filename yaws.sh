#!/bin/bash
VERSION="b0.0.14"
PID=$$
CONFIG_PATH="$HOME/.yaws/$PID"
STATIC_PATH="$HOME/.yaws/static"


PROFILE_LIST_FILE="$CONFIG_PATH/profiles"
EC2_INSTANCES_LIST_FILE="$CONFIG_PATH/ec2_instances"
EC2_INSTANCES_DETAILS_FILE="$CONFIG_PATH/ec2_instances_details"
EC2_INSTANCES_MENU_FILE="$CONFIG_PATH/ec2_instances_menu"
#
EC2_INSTANCES_PEM_FILES="$CONFIG_PATH/ec2_instances_pem"
#
EC2_INSTANCES_MANAGE_MENU_FILE="$CONFIG_PATH/ec2_instances_manage_menu"
#
EC2_INSTANCES_SCREEN_DETAILS_FILE="$CONFIG_PATH/ec2_instances_screen_details"

bold=$(tput bold)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
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
if [ ! -d $STATIC_PATH ];then mkdir -p $STATIC_PATH; fi

}

function usage
{
    echo "usage: yaws [[-e|--ec2]|[-d|--database]|[-h|--help]]"
}

function lines
{
MAX_LINES=$1
FROM_LINES=$2
if [ -z "$2" ];then FROM_LINES=1; fi
MAX_LINES=$(( MAX_LINES - FROM_LINES ))
for (( x=1; x<=$MAX_LINES; x++ )) do echo -e "\n"; done

}

function displayTime {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  printf '%04dd ' $D ; printf '%02dh ' $H; printf '%02dm ' $M; printf '%02ds' $S
}

function getTimeZone
{
if [ -f /etc/timezone ]; then
  OLSONTZ=`cat /etc/timezone`
elif [ -h /etc/localtime ]; then
  OLSONTZ=`readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///"`
else
  checksum=`md5sum /etc/localtime | cut -d' ' -f1`
  OLSONTZ=`find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1`
fi
echo $OLSONTZ
}


#********************************************************************************************************************************************************** 
# PROFILES
#**********************************************************************************************************************************************************

function createProfilesMenu
{
#Perfiles de AWS
cat ~/.aws/credentials | grep "\\[" | grep -v default | sed "s/\[//g" | sed "s/\]//g"  > $PROFILE_LIST_FILE
if [ ! -s ${PROFILE_LIST_FILE} ]; then
    echo "No profile found in ~/.aws/credentials"
    exit 1
fi
sort -f $PROFILE_LIST_FILE -o $PROFILE_LIST_FILE 
}

function DeleteProfileAction
{
PROFILE_SELECTED=$1

REAL_PROFILE_NAME=$(grep -i ${PROFILE_SELECTED} ~/.aws/credentials | sed "s/\[//g" | sed "s/\]//g")
BEGIN_LINE=$(sed -n "\|\[${REAL_PROFILE_NAME}\]|=" ~/.aws/credentials)

#Check if is the last profile in file

NUMBER_OF_LINES_NEXT_PROFILE=$(sed -n "/\[${REAL_PROFILE_NAME}\]/,/^\[/p" ~/.aws/credentials | wc -l)
NUMBER_OF_LINES_EOF=$(sed -n "/\[${REAL_PROFILE_NAME}\]/,/EOF/p" ~/.aws/credentials | wc -l)

if [ "${NUMBER_OF_LINES_EOF}" -gt "${NUMBER_OF_LINES_NEXT_PROFILE}" ]; then
    END_LINE=$(expr ${BEGIN_LINE} + ${NUMBER_OF_LINES_NEXT_PROFILE} - 2)
else
    END_LINE=$(expr ${BEGIN_LINE} + ${NUMBER_OF_LINES_EOF} - 1)
fi

sed -i".bak" "${BEGIN_LINE},${END_LINE}d" ~/.aws/credentials
rm ~/.aws/credentials.bak
}


function DeleteProfileOption
{
until [ "$selection" = "q" ]; do
     printManageProfilesActionMENUFooter
     read -r -n 2 selection
     echo ""
     case $selection in
         q ) clear;exit 0;;
         b ) break;;
         r ) printManageProfileMENU;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                PROFILE=$(sed "$selection!d" $PROFILE_LIST_FILE)
                echo "Profile selected to delete: $PROFILE"
                DeleteProfileAction $PROFILE
            fi;;
     esac
done
}

function printManageProfilesActionMENUFooter
{
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n "Choose profile | ${bold}${green}r${reset}efresh | ${bold}b${reset}ack | ${bold}${red}q${reset}uit: "
}

function printProfilesMENUHeader
{
clear
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e " ${bold}AWS PROFILES MENU : ${red}EC2 Mode${reset}"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
cat -n $PROFILE_LIST_FILE | tr '[:lower:]' '[:upper:]'
#lines 40 35
}

function printProfilesMENUFooter
{
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n "Choose profile | ${bold}${blue}m${reset}anage profiles | ${bold}${green}r${reset}efresh | ${bold}${red}q${reset}uit: "
}

function printManageProfilesMENUFooter
{
echo ""
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo -e "1. Create new profile"
echo -e "2. Delete profile"
echo -e "3. Change region profile"
echo -e "4. Edit profile settings"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n -e "Choose Option | ${bold}${green}r${reset}efresh | ${bold}b${reset}ack | ${bold}${red}q${reset}uit: "
}


function profilesMenu
{
createProfilesMenu
until [ "$selection" = "q" ]; do
     printProfilesMENUHeader
     printProfilesMENUFooter
     read -r -n 2 selection
     echo ""
     case $selection in
         q ) clear;exit 0;;
         r ) createProfilesMenu;;
         m ) printManageProfileMENU;;
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
if [ -z "$RETURN_VALUE" ];then RETURN_VALUE="-"; fi
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
    AUX_LAUNCH_TIME=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "LaunchTime")
    LAUNCH_TIME=$(date -j -f "%Y-%m-%dT%T" "$AUX_LAUNCH_TIME" "+%s" 2>/dev/null)
    ACTUAL_TIME=$(date -u "+%s")
    UPTIME=$(displayTime $(( ACTUAL_TIME - LAUNCH_TIME )))
    echo -e "$INSTANCE_SELECTED;$NAME;$PLATFORM;$STATUS;$PEM;$INSTANCETYPE;$DNS;$UPTIME" >> $MENU_FILE

done < $INSTANCES_FILE
sort -k 2 -t';' -f $MENU_FILE -o $MENU_FILE

}

function printManageProfileMENU
{
createProfilesMenu
until [ "$selection" = "q" ]; do
     printProfilesMENUHeader
     printManageProfilesMENUFooter
     read -r -n 1 selection
     echo ""
     case $selection in
         q ) clear;exit 0;;
         b ) break;;
         r ) createProfilesMenu;;
         1 ) echo "Create Profile";;
         2 ) DeleteProfileOption;;
         3 ) echo "Change region profile";;
         4 ) echo "Edit profile settings";;
     esac
done

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
    cat -n $MENU_FILE | column -t -s ";" | sed "s/running/${green}running${reset}/g" | sed "s/stopped/${red}stopped${reset}/g" | sed "s/stopping/${red}stopping${reset}/g"  | sed "s/pending/${yellow}pending${reset}/g"
fi
#lines 30 $(wc -l $MENU_FILE)
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
         q ) clear;exit 0;;
         r ) createEC2InstancesMENU $PROFILE_SELECTED;;
             #read -n 1;;
         * ) if [[ $selection =~ ^-?[0-9]+$ ]];then
                #echo "Seleccionada opcion : $selection"
                INSTANCE_SELECTED=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $1}')
                PEM=$(sed "${selection}!d" $MENU_FILE | awk -F ';' '{print $5".pem"}')
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
find $HOME/. -name $PEM_SEARCHED -type f > $PEM_FILE 2>/dev/null

PEM_FOUNDED=$(cat $PEM_FILE | wc -l)
#-exec stat -s {} \; | awk -F ";" '{OFS = ";"; delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["Var"] } { print vars["file"],vars["st_mtime"] }')
#echo "$PEM_FOUNDED pem(s) encontrado(s)"
#echo "ssh -i $(head -1 $PEM_FILE) ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress')"

#cat $PEM_FILE
}



#********************************************************************************************************************************************************** 
# EC2 Manage Instance
#**********************************************************************************************************************************************************

function createEC2DetailsScreen
{
PROFILE_SELECTED=$1 
INSTANCE_SELECTED=$2

MENU_FILE=${EC2_INSTANCES_SCREEN_DETAILS_FILE}_$PROFILE_SELECTED
DETAILS_FILE=${EC2_INSTANCES_DETAILS_FILE}_$PROFILE_SELECTED

#createEC2instancesDetailFile $PROFILE_SELECTED

if [ ! -f $DETAILS_FILE ]; then return 0; fi

rm -rf $MENU_FILE


    PUBLIC_DNS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PublicDnsName")
    PRIVATE_DNS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PrivateDnsName")
    PLATFORM=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "Platform");if [ "$PLATFORM" == "null" ]; then PLATFORM="linux"; fi
    STATUS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "State.Name")
    INSTANCETYPE=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "InstanceType")
    PUBLIC_IP=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PublicIpAddress")
    PRIVATE_IP=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "PrivateIpAddress")
    NAME=$(getKeyValuePropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "Tags" "Key" "Name" "Value")
    PEM=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "KeyName")
    AUX_LAUNCH_TIME=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "LaunchTime")
    SECURITY_GROUPS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "SecurityGroups[].GroupName") 
    SECURITY_GROUPS_IDS=$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED "SecurityGroups[].GroupId") 

    LAUNCH_TIME=$(date -j -f "%Y-%m-%dT%T" "$AUX_LAUNCH_TIME" "+%s" 2>/dev/null)
    ACTUAL_TIME=$(date "+%s")
    UPTIME=$(displayTime $(( ACTUAL_TIME - LAUNCH_TIME )))
    echo -e "ID ;: $INSTANCE_SELECTED;Name ;: $NAME" >> $MENU_FILE
    echo -e "Platform ;: $PLATFORM;STATUS ;: $STATUS ($UPTIME)" >> $MENU_FILE
    echo -e "PublicIP ;: $PUBLIC_IP;PrivateIP ;: $PRIVATE_IP" >> $MENU_FILE
    echo -e "Public DNS ;: $PUBLIC_DNS;Private DNS ;: $PRIVATE_DNS" >> $MENU_FILE
    echo -e "Security Groups ;: $SECURITY_GROUPS;;" >> $MENU_FILE
    echo -e "Security Groups ID;: $SECURITY_GROUPS_IDS;;" >> $MENU_FILE

}

function printEC2ManageInstanceMENU 
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
INSTANCE_NAME=$(getKeyValuePropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'Tags' 'Key' 'Name' 'Value')

printEC2ManageInstanceMENUHeader $PROFILE_SELECTED $INSTANCE_SELECTED $INSTANCE_NAME
printEC2ManageInstanceMENUFooter $PROFILE_SELECTED $INSTANCE_SELECTED $INSTANCE_NAME

}

function printEC2ManageInstanceMENUHeader
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
INSTANCE_NAME=$3
MENU_FILE=${EC2_INSTANCES_SCREEN_DETAILS_FILE}_$PROFILE_SELECTED

clear
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "AWS EC2 INSTANCES MENU" 
echo -e "SELECTED PROFILE : ${bold}$PROFILE_SELECTED${reset}"
echo -e "SELECTED INSTANCE : ${bold}$INSTANCE_SELECTED / $INSTANCE_NAME${reset}"
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"
cat $MENU_FILE | column -t -s ";" | sed "s/running/${green}running${reset}/g" | sed "s/stopped/${red}stopped${reset}/g" | sed "s/stopping/${red}stopping${reset}/g"  | sed "s/pending/${yellow}pending${reset}/g"


}

function printEC2ManageInstanceMENUFooter
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
INSTANCE_NAME=$3
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"
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
createEC2DetailsScreen $PROFILE_SELECTED $INSTANCE_SELECTED
until [ "$selection" = "b" ]; do
     printEC2ManageInstanceMENU $PROFILE_SELECTED $INSTANCE_SELECTED
     read -n 1 selection
     echo ""
     case $selection in
         b ) break;;
         q ) clear;exit 0;;
         r ) createEC2DetailsScreen $PROFILE_SELECTED $INSTANCE_SELECTED;;
         1 ) read -er -p"Username (Enter -> ubuntu) : " USERNAME
             if [ -z "$USERNAME" ];then USERNAME="ubuntu"; fi 
             ssh -o StrictHostKeyChecking=no -i "$(head -1 $PEM_FILE)" $USERNAME@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress')
             read -n 1;;
         2 ) read -er -p"Username (Enter -> ubuntu) : " USERNAME
             if [ -z "$USERNAME" ];then USERNAME="ubuntu"; fi 
             read -er -p"Files in $PROFILE_SELECTED -> $INSTANCE_NAME : " SOURCE_FILES
             read -er -p"Target path : "  TARGET_FILES
             scp -i "$(head -1 $PEM_FILE)" $USERNAME@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress'):$SOURCE_FILES $TARGET_FILES
             read -n 1;;     
         3 ) read -er -p"Username (Enter -> ubuntu) : " USERNAME
             if [ -z "$USERNAME" ];then USERNAME="ubuntu"; fi 
             read -er -p"Local Files : " SOURCE_FILES
             read -er -p"Target path in $PROFILE_SELECTED -> $INSTANCE_NAME : "  TARGET_FILES
             scp -i "$(head -1 $PEM_FILE)" $SOURCE_FILES ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress'):$TARGET_FILES
             read -n 1;;     
         4 ) read -er -p"Type command : " COMMAND
             ssh -o StrictHostKeyChecking=no -i "$(head -1 $PEM_FILE)" ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') $COMMAND
             read -n 1;;              
         5 ) read -er -p"Type absolute path to log : " LOG_PATH
             ssh -o StrictHostKeyChecking=no  -i "$(head -1 $PEM_FILE)" ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') less $LOG_PATH
             read -n 1;;  
         6 ) read -er -p"Write filter, empty to all : " GREP_FILTER
             ssh -o StrictHostKeyChecking=no -i "$(head -1 $PEM_FILE)" ubuntu@$(getPropertyEC2Instance $PROFILE_SELECTED $INSTANCE_SELECTED 'PublicIpAddress') ps -fea | grep "$GREP_FILTER"
             read -n 1;;
         7 ) echo "Network tools";;   
         8 ) echo "Monitoring tools";;   
         9 ) EC2InstancesManageToolsMenu $PROFILE_SELECTED $INSTANCE_SELECTED;;   
         * ) continue;;
     esac

done
}

function printEC2ManageToolsInstanceMENUFooter
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2
INSTANCE_NAME=$3
echo ""
echo "+--------------------------------------------------------------------------------------------------------------------------------------------------------+"
echo -e "1. Reboot instance"
echo -e "2. Stop instance"
echo -e "3. Start instance"
echo "----------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -n -e "Choose Option | ${bold}${green}r${reset}efresh | ${bold}b${reset}ack | ${bold}${red}q${reset}uit: "
}

function EC2InstancesManageToolsMenu
{
PROFILE_SELECTED=$1
INSTANCE_SELECTED=$2   
createEC2DetailsScreen $PROFILE_SELECTED $INSTANCE_SELECTED
until [ "$selection" = "b" ]; do
     printEC2ManageInstanceMENUHeader $PROFILE_SELECTED $INSTANCE_SELECTED
     printEC2ManageToolsInstanceMENUFooter $PROFILE_SELECTED $INSTANCE_SELECTED
     read -n 1 selection
     echo ""
     case $selection in
         b ) break;;
         q ) clear;exit 0;;
         r ) createEC2DetailsScreen $PROFILE_SELECTED $INSTANCE_SELECTED;;
         1 ) aws ec2 reboot-instances --instance-ids $INSTANCE_SELECTED --profile $PROFILE_SELECTED;;
         2 ) aws ec2 stop-instances --instance-ids $INSTANCE_SELECTED --profile $PROFILE_SELECTED;;
         3 ) aws ec2 start-instances --instance-ids $INSTANCE_SELECTED --profile $PROFILE_SELECTED;;
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
                                MODE="EC2"
                                profilesMenu
                                ;;
        -d | --database )       MODE="DATABASE"
                                profilesMenu
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

