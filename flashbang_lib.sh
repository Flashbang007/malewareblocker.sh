# lc_error() exits with exit information of last command of script
lc_error() {
        ERRORCODE=`echo $?`

        if [[ $ERRORCODE -ne 0 ]]; then
                echo -e "Error Number $CRED- $ERRORCODE -$CRESTORE"
                exit $ERRORCODE
        fi
}

# check_file() [FILE] Check if File exists and create
check_file() {
FILE="$1"

if [[ ! -f $FILE ]]
then
    touch $FILE
fi
}

# check_dir() [DIR]  Check if Directory exists and create
check_dir() {
DIR="$1"

if [[ ! -f $DIR ]]
then
    mkdir -p $DIR
fi
}

# check_root() Checks if user is root and exits if not
check_root(){
 if [ "$(id -u)" != "0" ]; then

        echo "You need to bee root to run this - No permission"
        exit 99
fi
}

# Colors $COL[R,G,B,Y,LR..] for Color. $COLD for Reset
COLD='\e[39m\e[0m'
COLR='\e[31m'
COLY='\e[33m'
COLG='\e[32m'
COLB='\e[34m'
COLLR='\e[91m'
COLLY='\e[93m'
COLLG='\e[92m'
COLLB='\e[94m'
COLBLINK='\e[5m'

# $SCRIPTNAME and $SCRIPTPATH for Name and Path
SCRIPTNAME="`basename \"$0\"`"
SCRIPTPATH="`dirname \"$0\"`"

# $PIPEFILE for Pushbulletervice dir is "/home/flashbang/Data/pushbullet.pipe"
PIPEFILE="/home/flashbang/Data/pushbullet.pipe"
