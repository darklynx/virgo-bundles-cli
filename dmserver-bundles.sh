#!/bin/bash

###########################################################
#
#  CLI tool to manage SpringSource dm Server OSGi bundles
#  Version: 1.0.0
#
#  License: MIT (see http://choosealicense.com/licenses/mit/)
#  Author: Vladimir Lyubitelev
#

VERSION=1.0.0
SDMSERVER_URL=http://localhost:8080

BUNDLE_FILE=
BUNDLE_NAME=
BUNDLE_VERSION=
BUNDLE_TYPE=bundle

VERBOSE=false

# First parameter is always a command
COMMAND=$1
shift

if [ -z "${COMMAND}" ]; then
	COMMAND=help
fi

# Parse arguments
while (($# > 0)); do
	case $1 in
	-f)
		BUNDLE_FILE=$2
		shift;
		;;
	-n)
		BUNDLE_NAME=$2
		shift;
		;;
	-v)
		BUNDLE_VERSION=$2
		shift;
		;;
	-t)
		BUNDLE_TYPE=$2
		shift;
		;;
	-user)
		SDMSERVER_USER=$2
		shift;
		;;
	-url)
		SDMSERVER_URL=$2
		shift;
		;;
	-verbose)
		VERBOSE=true
		;;
	*)
		echo "Unknown parameter: $1"
		;;
	esac
	shift
done

if [ "${COMMAND}" != "help" ]; then
	if [ ! $SDMSERVER_USER ]; then
		echo -n "Username [admin]: "
		read USERNAME
		if [ ! $USERNAME ]; then
			USERNAME=admin
		fi
		echo -n "Password: "
		read -s PASSWORD
		echo # calling 'read' with -s doesn't issue a newline
		SDMSERVER_USER=${USERNAME}:${PASSWORD}
	fi
fi

SILENT="-s"
if [ "${VERBOSE}" = "true" ]; then
	SILENT=""
fi

############################################
# Upload and deploy bundle
if [ "${COMMAND}" = "deploy" ]; then
	if [ -z "${BUNDLE_FILE}" ]; then
		echo "Error: location of OSGi bundle is not specified, use option -f"
		exit 1
	fi
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "Uploading and deploying bundle: ${BUNDLE_FILE}"
	fi
	
	# command
	RESULT=`curl ${SILENT} -u ${SDMSERVER_USER} -F "application=@${BUNDLE_FILE}" ${SDMSERVER_URL}/admin/web/artifact/deploy.htm`
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "dm Server response: ${RESULT}"
		echo "-------------------------"
	fi

	# analyze result
	MESSAGE=`echo "$RESULT" | grep -oEi "<h1>Artifact Console: '.+'</h1>" | cut -c 24- | rev | cut -c 7- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ -z "${MESSAGE}" ]; then
		echo "Failure"
		echo "Details: unexpected format of result: ${RESULT}"
		exit 2
	else
		if [ -z "`echo ${MESSAGE} | grep "Artifact deployed"`" ]; then
			echo "Failure"
			echo "Details: ${MESSAGE}"
			exit 2
		else
			echo "${MESSAGE}"
		fi
	fi
	
############################################
# Check bundle status
elif [ "${COMMAND}" = "status" ]; then
	if [ -z "${BUNDLE_NAME}" ]; then
		echo "Error: bundle symbolic name is not specified, use option -n"
		exit 1
	fi
	if [ -z "${BUNDLE_VERSION}" ]; then
		echo "Error: bundle version is not specified, use option -v"
		exit 1
	fi
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "Checking status of bundle: ${BUNDLE_NAME} version: ${BUNDLE_VERSION}"
	fi
	
	# command
	RESULT=`curl ${SILENT} -u ${SDMSERVER_USER} ${SDMSERVER_URL}/admin/web/artifact/data?parent=\&type=${BUNDLE_TYPE}\&name=${BUNDLE_NAME}\&version=${BUNDLE_VERSION}`	
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "dm Server response: ${RESULT}"
		echo "-------------------------"
	fi

	# analyze result
	BUNDLE_STATE=`echo "$RESULT" | grep -oEi ",label: '[A-Z]+',icon:" | cut -c 10- | rev | cut -c 8- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ -z "${BUNDLE_STATE}" ]; then
		echo "Failure"
		echo "Details: specified artefact is not found"
		exit 2
	else
		echo "Bundle state: ${BUNDLE_STATE}"
	fi
	
############################################
# Execute command: stop, start, uninstall, refresh
elif [[ "${COMMAND}" = "stop" || "${COMMAND}" = "start" || "${COMMAND}" = "uninstall" || "${COMMAND}" = "refresh" ]]; then
	if [ -z "${BUNDLE_NAME}" ]; then
		echo "Error: bundle symbolic name is not specified, use option -n"
		exit 1
	fi
	if [ -z "${BUNDLE_VERSION}" ]; then
		echo "Error: bundle version is not specified, use option -v"
		exit 1
	fi
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "Executing command: ${COMMAND} for bundle: ${BUNDLE_NAME} version: ${BUNDLE_VERSION}"
	fi
	
	# command
	RESULT=`curl ${SILENT} -u ${SDMSERVER_USER} ${SDMSERVER_URL}/admin/web/artifact/do/${COMMAND}?type=${BUNDLE_TYPE}\&name=${BUNDLE_NAME}\&version=${BUNDLE_VERSION}`

	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "dm Server response: ${RESULT}"
		echo "-------------------------"
	fi
	
	# analyze result
	MESSAGE=`echo "$RESULT" | grep -oEi "<h1>Artifact Console: '.+'</h1>" | cut -c 24- | rev | cut -c 7- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ -z "${MESSAGE}" ]; then
		echo "Failure"
		echo "Details: unexpected format of result: ${RESULT}"
		exit 2
	elif [ -z "`echo ${MESSAGE} | grep "successful"`" ]; then
		echo "Failure"
		echo "Details: ${MESSAGE}"
		exit 2
	else
		case ${COMMAND} in
		stop)
			echo "Stopped"
			;;
		start)
			echo "Started"
			;;
		uninstall)
			echo "Uninstalled"
			;;
		refresh)
			echo "Refreshed"
			;;
		*)
			echo "Something new: ${COMMAND}"
			;;
		esac
		echo "Details: ${MESSAGE}"
	fi

############################################
# Display help
else
	if [ "${COMMAND}" != "help" ]; then
		echo "Error: unknown command '${COMMAND}'"
	fi
	echo "SpringSource dm Server OSGi bundels management tool."
	echo "Version ${VERSION}"
	echo
	echo "Usage:"
	echo "  $0 <command> [options]"
	echo
	echo "Commands:"
	echo "  deploy     - upload and deploy OSGi bundle to dm Server, required options: -f"
	echo "  status     - check status of bundle at dm Server, required options: -n, -v"
	echo "  stop       - stop bundle at dm Server, required options: -n, -v"
	echo "  start      - start bundle at dm Server, required options: -n, -v"
	echo "  refresh    - refresh bundle at dm Server, required options: -n, -v"
	echo "  uninstall  - uninstall bundle from dm Server, required options: -n, -v"
	echo "  help       - display this help"
	echo
	echo "Options:"
	echo "  -f <path>  - location of OSGi bundle to upload, e.g. /opt/repo/org.slf4j.api-1.7.2.jar"
	echo "  -n <name>  - bundle symbolic name, e.g. org.slf4j.api"
	echo "  -v <ver>   - bundle version, e.g. 1.7.2"
	echo "  -t <type>  - bundle type, possible types: bundle, plan, par"
	echo "  -user <*>  - user name and password for basic auth, e.g. admin:passwd (will be prompted if not given)"
	echo "  -url <*>   - SpringSource dm Server URL, e.g. http://dmserver.internal:7070"
	echo "  -verbose   - enable verbose output"
	echo
	echo "Examples:"
	echo "  $0 deploy -f ~/dev/test-bundle-1.0.0-SNAPSHOT.jar"
	echo "  $0 status -n test-bundle -v 1.0.0.SNAPSHOT"
	echo "  $0 stop -n test-bundle -v 1.0.0.SNAPSHOT -url http://localhost:8081"
	echo "  $0 start -n test-bundle -v 1.0.0.SNAPSHOT -verbose"
	echo "  $0 uninstall -n test-bundle -v 1.0.0.SNAPSHOT"
	echo "  $0 status -n test-plan -v 2.0.0 -t plan"
fi
