#!/bin/bash

source /home/transpect-control/envvars.sh

LOGDIR=/data/svn/tmp/postcommit/$1
LOGFILE=$LOGDIR/$2.log
ERRORLOGFILE=$LOGDIR/$2.errors

mkdir -p $LOGDIR

echo $1 $2 > $LOGFILE
svnlook changed -r$2 $1 >> $LOGFILE 2>> $ERRORLOGFILE

echo BASEXHTTPPORT=$BASEXHTTPPORT

curl -X POST --data-binary @$LOGFILE http://localhost:$BASEXHTTPPORT/control-backend/default/process-commit-log 2>&1 >> $ERRORLOGFILE
