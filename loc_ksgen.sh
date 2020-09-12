#!/usr/bin/env bash

cd "$(dirname "$0")"
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 191)
BLUE=$(tput setaf 4)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)

function getip() {
IPADDR=''
while [ "$IPADDR" = "" ]; do
    echo -n "${GREEN} ▶${NORMAL} Set KS file IP addr: "
    read IPADDR
done
		}

function gethostname() {
DSUNAME=''
while [ "$DSUNAME" = "" ]; do
    echo -n "${GREEN} ▶${NORMAL} Set KS file hostname: "
    read DSUNAME
done
		}

function setdata() {
printf '%s\n'  "${BRIGHT}${GREEN}======== Summary ========${NORMAL}"
printf '%s\n' "${BLUE}Entered hostname:${NORMAL} ${BRIGHT}$DSUNAME${NORMAL}"
printf '%s\n' "${BLUE}Entered IP:${NORMAL} ${BRIGHT}$IPADDR${NORMAL}"
GATEWAY=$(echo $IPADDR | sed 's/[0-9]\+/1/4')
printf '%s\n' "${BLUE}Gateway IP:${NORMAL} $GATEWAY"
ROOTPW=$(pwgen -s -n 12 1)
printf '%s\n' "${BLUE}SU password is:${NORMAL} ${RED}$ROOTPW${NORMAL}"
		}

function deployloc() {
PXEPATH='/home/repo/mirror/mirror.yandex.ru/preseed/ks/'
if [ -n "$1" -a "$2" = "put" ]
	then
	cp $1 $PXEPATH
	chown sftpuser. $PXEPATH/$1
	elif [ -n "$1" -a "$2" = "remove" ]
                then
		echo "KS file will be removed in 10 minutes according to at job"
		at now +10 minute <<< "rm -f $PXEPATH/$1" 2>/dev/null
                else
printf '%b\n' "\nUsing: \ndeploy <filename> <action>  \n\t filename - name of kickstart file \n\t action -  put or remove\n"
fi
		}

function createks6() {
sed -i "s/^rootpw.*/rootpw $ROOTPW/g" ks6
sed -i "s/^network --onboot.*/network --onboot=yes --bootproto=static --ip=$IPADDR --netmask=255.255.255.0 --gateway=$GATEWAY --nameserver=1.1.1.1 --hostname=$DSUNAME/g" ks6
sed -i "s/^volgroup vg_.*/volgroup vg_$DSUNAME --pesize=4096 pv.008002/g" ks6
sed -i "s|^logvol \/.*|logvol \/ --fstype=ext4 --name=lv_root --vgname=vg_$DSUNAME --grow --size=1024 --maxsize=51200|g" ks6
sed -i "s/^logvol swap .*/logvol swap --name=lv_swap --vgname=vg_$DSUNAME --grow --size=2048 --maxsize=2048/g" ks6
		}

function createks7() {
sed -i "s/^rootpw.*/rootpw $ROOTPW/g" ks7
sed -i "s/^network  --bootproto.*/network  --bootproto=static --device=link --gateway=$GATEWAY --ip=$IPADDR --nameserver=1.1.1.1 --netmask=255.255.255.0 --ipv6=auto --activate/g" ks7
sed -i "s/^network  --hostname.*/network  --hostname=$DSUNAME/g" ks7
		}

function createks8() {
sed -i "s/^rootpw.*/rootpw $ROOTPW/g" ks8
sed -i "s/^network  --bootproto.*/network  --bootproto=static --device=link --gateway=$GATEWAY --ip=$IPADDR --nameserver=1.1.1.1 --netmask=255.255.255.0 --ipv6=auto --activate/g" ks8
sed -i "s/^network  --hostname.*/network  --hostname=$DSUNAME/g" ks8
		}

function telegram() {
token='YOUR_BOT_TOKEN'
chat='YOUR_CHAT_ID'
subj="$1"
message="$2"

/usr/bin/curl -s --header 'Content-Type: application/json' --request 'POST' --data "{\"chat_id\":\"${chat}\",\"text\":\"${subj}\n${message}\",\"parse_mode\":\"html\"}" "https://api.telegram.org/bot${token}/sendMessage"
		}

function ifksplaced() {
if [[ ! -f "ks6" && ! -f "ks7" && ! -f "ks8" ]]
    then
    curl -s -O https://raw.githubusercontent.com/rootwheel/ksgenerator/master/CentKS/ks6 \
	    -O https://raw.githubusercontent.com/rootwheel/ksgenerator/master/CentKS/ks7 \
	    -O https://raw.githubusercontent.com/rootwheel/ksgenerator/master/CentKS/ks8
fi
		}

printf '%s' "Select OS version in CentOS ${BRIGHT}[6]${NORMAL}, CentOS ${BRIGHT}[7]${NORMAL}, CentOS ${BRIGHT}[8]${NORMAL}: "

read KEYPRESS

case "$KEYPRESS" in
	"6" )
	getip
	gethostname
	ifksplaced
	setdata
	createks6
	;;

	"7" )
	getip
	gethostname
	ifksplaced
	setdata
       	createks7
       	;;

	"8" )
	getip
	gethostname
	ifksplaced
        setdata
        createks8
       	;;

	* )
	printf '%s\n' "[${RED}X${NORMAL}] Wrong versiong of CentOS selected"
	;;
esac

if [[ ("$KEYPRESS" = "6") || ("$KEYPRESS" = "7") || ("$KEYPRESS" = "8") ]]
	then
	deployloc ks$KEYPRESS put > /dev/null
	deployloc ks$KEYPRESS remove

### Log control ###
#	  	printf '%s\n' "[$(date --rfc-3339=seconds)]: $*logged user $(last -1 | awk 'NR==1 {print $1,$3; exit}') creates a KS$KEYPRESS file for $DSUNAME $IPADDR $ROOTPW " >> ksgen.log

	else
		printf '%s\n' "[${RED}X${NORMAL}] Valid Key not pressed"
fi

