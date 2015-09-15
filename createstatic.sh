#!/bin/bash
WORKDATE=`date "+%m%d%Y"`

LOG_FILE=static_${WORKDATE}.log

source ../ini/settings.ini
source ../xtnutils/logging.sh

sendlog()
{
MAILPRGM=`which mutt`
if [ -z $MAILPRGM ]; then
true
else
sudo $MAILPRGM -e 'set content_type="text/plain"' $STATICMTO -s "Reporting Database Status" < ${LOG_FILE}
RET=$?
rm ${LOG_FILE}
fi
}

createstatic()
{
log_exec sudo pg_ctlcluster ${PGVER} $STATICCLUSTER stop --force
RET=$?
if [ $RET -eq 1 ]; then
log "Couldn't stop cluster"
sendlog
exit 1;
else
log "Stopped $STATICCLUSTER"
fi

log_exec sudo pg_ctlcluster ${PGVER} $STATICCLUSTER start
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't start cluster"
sendlog
exit 1;
else
log "Restarted $STATICCLUSTER"
fi

# Alternate SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${STATICDB}'; DROP DATABASE ${STATICDB};
log_exec sudo dropdb -U $PGUSER -p $STATICPORT $STATICDB
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't drop db"
sendlog
 exit 1;
else
log "Dropped ${STATICDB} on ${STATICPORT}"
fi

log_exec sudo createdb -U $PGUSER -p $STATICPORT $STATICDB
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't create db"
sendlog
 exit 1;
else
log "Created ${STATICDB}"
fi

log_exec sudo pg_restore --host $PGHOST  --port $STATICPORT -j10 --username $PGUSER -d $STATICDB ${ARCHIVEDIR}/${STATICBACKUPFILE}
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't restore db ${STATICDB} on ${STATICPORT}"
sendlog
 exit 1;
else
log "Restored ${STATICDB} from ${STATICBACKUPFILE}"
log " "
log "${STATICDBCOPY} is now Available"
fi

}

createstaticdbcopy()
{
log "Creating ${STATICDBCOPY} Database"
log_exec sudo $PGBIN/psql -U $PGUSER -h $PGHOST -p $STATICPORT -c "DROP DATABASE ${STATICDBCOPY};"
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't drop ${STATICDBCOPY} db"
sendlog
 exit 1;
fi

log_exec sudo $PGBIN/psql -U $PGUSER -h $PGHOST -p $STATICPORT -c "CREATE DATABASE ${STATICDBCOPY} OWNER admin TEMPLATE ${STATICDB};"
RET=$?
if [ $RET -eq 1 ]; then
 log "Couldn't create ${STATICDBCOPY} db"
sendlog
 exit 1;
else
log "Created ${STATICDBCOPY} from ${STATICDB}"
log " "
log "${STATICDBCOPY} is now Available"
fi

}

if [ -f ${ARCHIVEDIR}/${STATICBACKUPFILE} ];
 then
log "Found ${STATICBACKUPFILE} in ${ARCHIVEDIR}"
log "Proceeding.."
createstatic
createstaticdbcopy
log "The process is now complete!"
sendlog
exit 0;

else
 log "Can't find ${ARCHIVEDIR}/${STATICBACKUPFILE}"
 log "Quitting!"
 log "Contact your IT Admins."

sendlog

exit 0;
fi

