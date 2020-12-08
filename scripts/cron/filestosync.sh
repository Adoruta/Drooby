#!/bin/bash
if pidof -o %PPID -x "$(basename $0)"; then
	echo Already running!
	exit 1
fi

source /opt/Gooby/menus/variables.sh
source ${CONFIGS}/Docker/.env

# Check to see if anything needs to be cached locally.  Doing this before the sync allows new files to be copied locally first.

[ -f ${HOME}/bin/localcache ] && ${HOME}/bin/localcache

# Load existing variables and use them as defaults, if available

AGE=0	# How many minutes old a file must be before copying/deleting
LOG=${LOGS}/mounter-sync.log
TEMPFILE="/tmp/filestosync"
TOTALSIZE=0

# Fix dates in the future

find ${UPLOADS}/ ! -path "*Downloads*" ! -iname "*.partial~" -type f -mmin -0 -exec touch "{}" -d "$(date -d "-5 minutes")" \;

# Identify files needing to be copied

find ${UPLOADS}/ ! -path "*Downloads*" ! -iname "*.partial~" -type f -cmin +${AGE} | sed 's|'${UPLOADS}/'||' | sort > ${TEMPFILE}

# Report files
echo Files to sync:
if [[ -s ${TEMPFILE} ]]
then
	while IFS= read -r FILE
	do
		rclone rc core/stats --user ${RCLONEUSERNAME} --pass ${RCLONEPASSWORD} | jq '.transferring' | grep "${UPLOADS}/${FILE}" > /dev/null
		RUNCHECK=${?}
		if [[ ${RUNCHECK} -gt 0 ]]; then
			BYTES=$(du "${UPLOADS}/${FILE}" | cut -f1)
			BYTESH=$(du -h "${UPLOADS}/${FILE}" | cut -f1)
			echo "${FILE} (${BYTESH})"
			TOTALSIZE=$((TOTALSIZE+BYTES))
		fi
	done < ${TEMPFILE}
else
	echo No files awaiting sync | tee -a ${LOG}
fi
echo
echo Total size:
/bin/sizer `expr $TOTALSIZE \* 1024`
# Cleanup letovers

rm ${TEMPFILE}