#!/bin/sh
# Setup script for OSSEC UI
# Author: Daniel B. Cid <dcid@ossec.net>


# Finding my location
LOCAL=`dirname $0`;
cd $LOCAL
PWD=`pwd`
ERRORS=0;

trap "rm -f $TMPFILE; exit" SIGHUP SIGINT SIGTERM

# Looking for echo -n
ECHO="echo -n"
hs=`echo -n "a"`
if [ ! "X$hs" = "Xa" ]; then
    ls "/usr/ucb/echo" > /dev/null 2>&1
    if [ $? = 0 ]; then
        ECHO="/usr/ucb/echo -n"
    else
        ECHO=echo
    fi
fi

# Looking for htpasswd
HTPWDCMD="htpasswd"
ls "`which $HTPWDCMD`" > /dev/null 2>&1
if [ ! $? = 0 ]; then
    HTPWDCMD="htpasswd2"
    ls "`which $HTPWDCMD`" > /dev/null 2>&1
    if [ ! $? = 0 ]; then
        HTPWDCMD=""
    fi
fi


# Default options
HT_DIR_ACCESS="deny from all"
HT_FLZ_ACCESS="AuthUserFile $PWD/.htpasswd"
HT_DEFAULT="htaccess_def.txt"


echo "Setting up ossec ui..."
echo ""


ls $HT_DEFAULT > /dev/null 2>&1
if [ ! $? = 0 ]; then
    echo "** ERROR: Could not find '$HT_DEFAULT'. Unable to continue."
    ERRORS=1;
fi


# 1- Create .htaccess blocking access to private directories.
PRIV_DIRS="site lib tmp"
mkdir tmp >/dev/null 2>&1
chmod 777 tmp
for i in $PRIV_DIRS; do
    echo $HT_DIR_ACCESS > ./$i/.htaccess;
done

# 2- Create. htaccess blocking access to .sh and config files.
echo $HT_FLZ_ACCESS > ./.htaccess;
echo "" >> ./.htaccess;
cat $HT_DEFAULT >> ./.htaccess;


# 3- Create password
while [ 1 ]; do
    if [ "X$MY_USER" = "X" ]; then
        $ECHO "Username: "
        read MY_USER;
    else
        break;
    fi
done

if [ "X$HTPWDCMD" = "X" ]; then
    echo "** ERROR: Could not find htpasswd. No password set."
    ERRORS=1;
else
    $HTPWDCMD -c $PWD/.htpasswd $MY_USER
    if [ ! $? = 0 ]; then
        ERRORS=1;
    fi
fi

# Adjust permissions for ossec-wui
OSSEC=`grep ^ossec: /etc/group`
if grep ^ossec: /etc/group > /dev/null 2>&1; then
    echo "Enter your web server user name (e.g. apache, www, nobody, www-data, ...)"
    read HTTPDUSER
    if ! (echo $OSSEC | grep -w $HTTPDUSER) > /dev/null 2>&1; then
        NEWLINE="$OSSEC,$HTTPDUSER"
        NEWLINE=`echo $NEWLINE | sed -e 's/:,/:/'`
        TMPFILE=`mktemp`
        sed "s/$OSSEC/$NEWLINE/" /etc/group > $TMPFILE
        cp $TMPFILE /etc/group
        rm -f $TMPFILE
        echo "You must restart your web server after this setup is done."
    fi
else
    echo "ossec group does not exist."
    ERRORS=1
fi

if [ $ERRORS = 0 ]; then
    echo ""
    echo "Setup completed successfully."
else
    echo ""
    echo "Setup failed to complete."
fi
