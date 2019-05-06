#!/bin/bash

source /usr/local/lib/flashbang_lib.sh
# lc_error() exits with exit information of last command of script
# check_file() [FILE] Check if File exists and create
# check_dir() [DIR]  Check if Directory exists and create
# check_root() Checks if user is root and exits if not
# Colors $COL[R,G,B,Y,LR..] for Color. $COLD for Reset
# $SCRIPTNAME and $SCRIPTPATH for Name and Path
# $PIPEFILE for Pushbulletervice dir is "/home/flashbang/Data/pushbullet.pipe"

# ------Settings------
WORKDIR="/home/flashbang/Data"
MAILUSER=root
DBBLOCKED="/etc/bind/db.blocked"
NAMEDBLOCKED="/etc/bind/named.conf.blocked"
NAMEDCONF="/etc/bind/named.conf"

FILENAME="$WORKDIR/domains_to_block"
WHITELIST="$WORKDIR/whitelist.txt"
BLACKLIST="$WORKDIR/dblacklist.txt"
LOG="$WORKDIR/$SCRIPTNAME_log.txt"

BLOCKDOMAINSARRAY=( \
#"https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
#"https://blocklist.kowabit.de/list.txt" \
#"https://hosts-file.net/ad_servers.txt" \
#"https://isc.sans.edu/feeds/suspiciousdomains_Low.txt" \
#"https://hosts-file.net/fsa.txt" \
#"https://hosts-file.net/hjk.txt" \
#"https://raw.githubusercontent.com/notracking/hosts-blocklists/master/hostnames.txt" \
#"https://hosts.ubuntu101.co.za/domains.list" \
"https://raw.githubusercontent.com/anudeepND/youtubeadsblacklist/master/domainlist.txt" \
"http://malwaredomains.lehigh.edu/files/justdomains" \
"https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&showintro=1&mimetype=plaintext" \
"http://someonewhocares.org/hosts/zero/hosts" \
"http://winhelp2002.mvps.org/hosts.txt" \
"https://adaway.org/hosts.txt" \
"https://hosts-file.net/emd.txt" \
"https://hosts-file.net/exp.txt" \
)
#---------------------
# functions ----------
wait_time(){
        # wait a bit, since bind is sluggish
        echo -e "-> Wait for bind9 to restart: "
                secs=$((7))
                while [ $secs -gt 0 ]; do
                echo -ne " $secs\033[0K\r"
                sleep 1
        : $((secs--))
done

}


cleanup(){
        rm $FILENAME*

}


restart_bind(){
        echo "-> Restarting bind9:"
        systemctl restart bind9
        wait_time
        systemctl status bind9 --no-pager

}


reset_blockfile(){
        echo "-> Cleaning blockfile:"
        cp $NAMEDBLOCKED $NAMEDBLOCKED.analyse
        > $NAMEDBLOCKED
        restart_bind
}


reset_if_lc_fail(){
        ERRORCODE=$(echo $?)
        [ ! -z "$1" ] && LC=", $1" || LC=""

        if [[ $ERRORCODE -ne 0 ]]; then
                reset_blockfile
                cleanup
                echo "Fehler bei $SCRIPTNAME;Letzter Befehl$LC produzierte Fehlercode - $ERRORCODE." | tee $PIPEFILE
                exit 1
        fi
}


download_all_lists(){
        for BLOCKDOMAIN in "${BLOCKDOMAINSARRAY[@]}"; do
                wget "$BLOCKDOMAIN" -O - >> $FILENAME
        done
}


clean_list(){
        echo "-> Cleaning list"
        # clean db file from ^M carriage return"
        perl -p -i -e "s/\r//g" $FILENAME

        # clean all ips, komments and whitespaces"
        sed -r -i 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}//;s/[ \t]*//;s/[#<!:].*$//;/^$/d;s/[[:space:]]+//' $FILENAME

        # find no matching domains"
        egrep "^[_a-zA-Z0-9-]{1,}\.[_a-zA-Z0-9-]{1,}.*$" $FILENAME | awk '{print tolower($0)}' > $FILENAME.clean # still double entrys
        cp $FILENAME.clean $FILENAME

}


add_blacklist(){
        echo "-> Adding blacklist"
        if [ -f $BLACKLIST ]; then
                cat $BLACKLIST >> $FILENAME
        fi

}


make_uniq(){
        echo "-> Making list uniq"
        sort $FILENAME | uniq | sort | uniq > $FILENAME.uniq
        cp $FILENAME.uniq $FILENAME

}


substitute_whitelist(){
        echo "-> Substituting whitelist"
        if [ -f $WHITELIST ]; then
                echo "-> Removing whitelist domains"
                grep -v -f $WHITELIST $FILENAME > $FILENAME.white
                cp $FILENAME.white $FILENAME
        fi

}


create_db(){
        echo "-> Creating $NAMEDBLOCKED"
        for DOMAIN in $(cat $FILENAME) ; do
                echo "zone \"$DOMAIN\" {type master; file \"/etc/bind/db.blocked\";};" >> $NAMEDBLOCKED
        done

        echo 'zone "blocked.local" {type master; file "/etc/bind/db.blocked";};' >> $NAMEDBLOCKED
        echo 'zone "178.168.192.in-addr.arpa" {type master; file "/etc/bind/db.178.168.192";};' >> $NAMEDBLOCKED

}


check_db(){
        echo "-> Checking $NAMEDBLOCKED"
        named-checkconf $NAMEDBLOCKED | tee $LOG
        reset_if_lc_fail "named-checkconf"
        echo "OK"
}

#---------------------
check_dir $WORKDIR

if [[ "$1" == "-d" ]]; then
        reset_blockfile
        exit 0
fi

# Check if Bind ist running
[[ $(systemctl status bind9.service > /dev/null ; echo $?) -ne 0  ]] && { echo "Bind is not installed or running. Please Download or Check" ; exit 2 ; }

# Check if Blockfile exists
if [[ ! -f $DBBLOCKED ]]; then
        touch $DBBLOCKED

        echo "
;
; BIND data file for example.local
;
$TTL    3600
@       IN      SOA     hans.fritz.box. root.hans.fritz.box. (
                            2014052101         ; Serial
                                  7200         ; Refresh
                                   120         ; Retry
                               2419200         ; Expire
                                  3600)        ; Default TTL
                NS      hans.fritz.box
        IN      A       127.0.0.1; This wildcard entry means that any permutation of xxx.nau
ghtydomain.com gets directed to the designated address
@       IN      A       127.0.0.1; This wildcard entry means that any permutation of xxx.nau
ghtydomain.com gets directed to the designated address
*       IN      A       127.0.0.1; This wildcard entry means that any permutation of xxx.nau
ghtydomain.com gets directed to the designated address
" > $DBBLOCKED
fi

# check if blockefile is included
if grep "include \"$NAMEDBLOCKED\";" > /dev/null $NAMEDCONF; then
        :
else
        echo "inclde satement is added to $NAMEDCONF"
        echo "include \"$NAMEDBLOCKED\";"
fi

# get clean Files
> $NAMEDBLOCKED
> $FILENAME
> $FILENAME.dirty
> $FILENAME.clean

# Make blocked conf file
check_file $NAMEDBLOCKED

download_all_lists

clean_list

add_blacklist

make_uniq

substitute_whitelist

create_db

check_db

restart_bind
reset_if_lc_fail "restart_bind"

cleanup
exit 0
