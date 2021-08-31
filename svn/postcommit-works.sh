#!/bin/bash

# replace it for installation, for example:
# sed -e 's@/home/transpect-control@'"$HOME"'@' $1/backend/svn/postcommit-works.sh
source /home/transpect-control/envvars.sh

if [ -z $LOGDIRBASE ]; then
    LOGDIRBASE=/data/svn/tmp/postcommit
fi
if [ -z $BASEXBASEURL ]; then
    BASEXBASEURL=http://localhost:$BASEXHTTPPORT
fi

LOGDIR=$LOGDIRBASE$1
LOGFILE=$LOGDIR/$2.log
ERRORLOGFILE=$LOGDIR/$2.errors

mkdir -p $LOGDIR

echo $1 $2 > $LOGFILE
svnlook changed -r$2 $1 >> $LOGFILE 2>> $ERRORLOGFILE

curl -X POST --data-binary @$LOGFILE $BASEXBASEURL/control-backend/default/process-commit-log 2>&1 >> $ERRORLOGFILE
