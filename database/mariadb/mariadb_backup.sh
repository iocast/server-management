#!/bin/bash

# Adapted from from Marcp
#   -> http://wiki.postgresql.org/wiki/Automated_Backup_on_Linux

###########################
####### LOAD CONFIG #######
###########################
 
while [ $# -gt 0 ]; do
	case $1 in
		-c)
		if [ -r "$2" ]; then
			source "$2"
			shift 2
		else
			${ECHO} "Ureadable config file \"$2\""
			exit 1
		fi
		;;
		*)
		${ECHO} "Unknown Option \"$1\""
		exit 2
		;;
	esac
done

SCRIPTPATH=$(cd ${0%/*} && pwd -P)

if [ $# = 0 ]; then
	source $SCRIPTPATH/mariadb_backup.config
fi;



###########################
#### PRE-BACKUP CHECKS ####
###########################
 
# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ]; then
	echo "This script must be run as $BACKUP_USER. Exiting."
	exit 1;
fi;
 
 
###########################
### INITIALISE DEFAULTS ###
###########################
 
if [ ! $HOSTNAME ]; then
	HOSTNAME="localhost"
fi;
 
if [ ! $USERNAME ]; then
	USERNAME="root"
fi;
 
 
###########################
#### START THE BACKUPS ####
###########################
 
 
FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y-\%m-\%d`/"
 
echo "Making backup directory in $FINAL_BACKUP_DIR"
 
if ! mkdir -p $FINAL_BACKUP_DIR; then
	echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!"
	exit 1;
fi;
 
 
###########################
### SCHEMA-ONLY BACKUPS ###
###########################
 
for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
do
	SCHEMA_ONLY_CLAUSE="$SCHEMA_ONLY_CLAUSE schema_name like '%$SCHEMA_ONLY_DB%' or"
done

SCHEMA_ONLY_QUERY="select schema_name from schemata where ${SCHEMA_ONLY_CLAUSE:1:-3} order by schema_name;"

echo -e "\n\nPerforming schema-only backups"
echo -e "--------------------------------------------\n"

if [[ -n "$SCHEMA_ONLY_CLAUSE" ]]; then
	if [ -f $SCRIPTPATH/my.cnf ]; then
		SCHEMA_ONLY_DB_LIST_QUERY="$SCHEMA_ONLY_DB_LIST_QUERY --defaults-extra-file=$SCRIPTPATH/my.cnf"
	else
		SCHEMA_ONLY_DB_LIST_QUERY="$SCHEMA_ONLY_DB_LIST_QUERY -p"
	fi
	SCHEMA_ONLY_DB_LIST=`mysql $SCHEMA_ONLY_DB_LIST_QUERY -h "$HOSTNAME" -u "$USERNAME" -B --skip-column-names -e "$SCHEMA_ONLY_QUERY" information_schema`
fi

echo -e "The following databases were matched for schema-only backup:\n${SCHEMA_ONLY_DB_LIST}\n"
 
for DATABASE in $SCHEMA_ONLY_DB_LIST
do
	echo "Schema-only backup of $DATABASE"
	
	if [ -f $SCRIPTPATH/my.cnf ]; then
		DUMP_QUERY="$DUMP_QUERY --defaults-extra-file=$SCRIPTPATH/my.cnf"
	else
		DUMP_QUERY="$DUMP_QUERY -p"
	fi
	if ! mysqldump $DUMP_QUERY -d -h "$HOSTNAME" -u "$USERNAME" "$DATABASE" | gzip > $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress; then
		echo "[!!ERROR!!] Failed to backup database schema of $DATABASE"
	else
		mv $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE"_SCHEMA.sql.gz
	fi
done
 
 
###########################
###### FULL BACKUPS #######
###########################
 
for SCHEMA_ONLY_DB in ${SCHEMA_ONLY_LIST//,/ }
do
	EXCLUDE_SCHEMA_ONLY_CLAUSE="$EXCLUDE_SCHEMA_ONLY_CLAUSE and schema_name not like '%$SCHEMA_ONLY_DB%'"
done

FULL_BACKUP_QUERY="select schema_name from schemata where schema_name not in ('information_schema', 'performance_schema', 'mysql') $EXCLUDE_SCHEMA_ONLY_CLAUSE order by schema_name;"

echo -e "\n\nPerforming full backups"
echo -e "--------------------------------------------\n"

if [ -f $SCRIPTPATH/my.cnf ]; then
	DB_LIST_QUERY="$DB_LIST_QUERY --defaults-extra-file=$SCRIPTPATH/my.cnf"
else
	DB_LIST_QUERY="$DB_LIST_QUERY -p"
fi

for DATABASE in `mysql $DB_LIST_QUERY -h "$HOSTNAME" -u "$USERNAME" -B --skip-column-names -e "$FULL_BACKUP_QUERY" information_schema`
do
	if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
	then
		echo "Plain backup of $DATABASE"
		
		if [ -f $SCRIPTPATH/my.cnf ]; then
			DUMP_QUERY="$DUMP_QUERY --defaults-extra-file=$SCRIPTPATH/my.cnf"
		else
			DUMP_QUERY="$DUMP_QUERY -p"
		fi
		
		if ! mysqldump $DUMP_QUERY -h "$HOSTNAME" -u "$USERNAME" "$DATABASE" | gzip > $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress; then
			echo "[!!ERROR!!] Failed to produce plain backup database $DATABASE"
		else
			mv $FINAL_BACKUP_DIR"$DATABASE".sql.gz.in_progress $FINAL_BACKUP_DIR"$DATABASE".sql.gz
		fi
	fi

done

echo -e "\nAll database backups complete!"