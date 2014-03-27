#!/bin/bash

###########################################################
#
#  CLI tool to manage Virgo OSGi bundles
#  Version: 1.0.4
#
#  License: MIT (see http://choosealicense.com/licenses/mit/)
#  Author: Vladimir Lyubitelev
#

VERSION=1.0.4
VIRGO_URL=http://localhost:8080

BUNDLE_FILE=
BUNDLE_NAME=
BUNDLE_VERSION=
BUNDLE_TYPE=bundle
BUNDLE_CUSTOM_TYPE=

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
		BUNDLE_CUSTOM_TYPE=$2
		shift;
		;;
	-user)
		VIRGO_USER=$2
		shift;
		;;
	-url)
		VIRGO_URL=$2
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

# Request user/password for relevant commands
case ${COMMAND} in
deploy|status|stop|start|uninstall|refresh|list)
	if [ -z "$VIRGO_USER" ]; then
		echo -n "Username [admin]: "
		read USERNAME
		if [ -z "$USERNAME" ]; then
			USERNAME=admin
		fi
		echo -n "Password: "
		read -s PASSWORD
		echo # calling 'read' with -s doesn't issue a newline
		VIRGO_USER=${USERNAME}:${PASSWORD}
	fi
esac

SILENT="-s"
if [ "${VERBOSE}" = "true" ]; then
	SILENT=""
fi

# Auto-detect bundle region
case ${BUNDLE_TYPE} in
bundle)
	BUNDLE_REGION=org.eclipse.virgo.region.user
	;;
plan)
	BUNDLE_REGION=global
	;;
par)
	BUNDLE_REGION=global
	;;
configuration)
	BUNDLE_REGION=global
	;;
*)
	echo "Error: unsupported bundle type '${BUNDLE_TYPE}'"
	exit 1
esac

case ${COMMAND} in
############################################
# Upload and deploy bundle
deploy)
	if [ -z "${BUNDLE_FILE}" ]; then
		echo "Error: location of OSGi bundle is not specified, use option -f"
		exit 1
	fi
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "Uploading and deploying bundle: ${BUNDLE_FILE}"
	fi
	
	# command
	RESULT=`curl ${SILENT} -u ${VIRGO_USER} -F "file=@${BUNDLE_FILE}" ${VIRGO_URL}/admin/upload`
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "Virgo response: ${RESULT}"
		echo "-------------------------"
	fi

	# analyze result
	MESSAGE=`echo "$RESULT" | grep -oEi "<ol id=\"uploadResults\"><li>.+</li>" | cut -c 28- | rev | cut -c 6- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ -z "${MESSAGE}" ]; then
		echo "Failure"
		echo "Details: unexpected format of result: ${RESULT}"
		exit 2
	else
		if [ -z "`echo ${MESSAGE} | grep ".* deployed as .*"`" ]; then
			echo "Failure"
			echo "Details: ${MESSAGE}"
			exit 2
		else
			DEPLOYED_NAME=`echo ${MESSAGE} | grep -oEi " - (.+):" | cut -c 4- | rev | cut -c 2- | rev`
			DEPLOYED_VERSION=`echo ${MESSAGE} | grep -oEi ": (.+)" | cut -c 3-`
			DEPLOYED_TYPE=`echo ${MESSAGE} | grep -oEi "deployed as (.+) - " | cut -c 13- | rev | cut -c 4- | rev`
			echo "Deployed: name=${DEPLOYED_NAME}, version=${DEPLOYED_VERSION}, type=${DEPLOYED_TYPE}"
		fi
	fi
	;;
############################################
# Check bundle status
status)
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
	RESULT=`curl ${SILENT} -u ${VIRGO_USER} ${VIRGO_URL}/admin/jolokia/read/org.eclipse.virgo.kernel:artifact-type=${BUNDLE_TYPE},name=${BUNDLE_NAME},region=${BUNDLE_REGION},type=ArtifactModel,version=${BUNDLE_VERSION}`	
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "Virgo response: ${RESULT}"
		echo "-------------------------"
	fi

	# analyze result
	RESULT_STATUS=`echo "$RESULT" | grep -oEi ",\"status\":[0-9]*," | cut -c 11- | rev | cut -c 2- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ "${RESULT_STATUS}" = "200" ]; then
		BUNDLE_STATE=`echo "$RESULT" | grep -oPi ",\"State\":\".+?\"," | cut -c 11- | rev | cut -c 3- | rev`
		echo "Bundle state: ${BUNDLE_STATE}"
	else
		MESSAGE=`echo "$RESULT" | grep -oPi "\"error\":\".+?\"" | cut -c 10- | rev | cut -c 2- | rev`
		if [ -z "${MESSAGE}" ]; then
			MESSAGE=${RESULT}
		fi
		
		echo "Failure"
		echo "Details: ${MESSAGE}"
		exit 2
	fi
	;;
############################################
# List bundles
list)
	# command
	RESULT=`curl ${SILENT} -u ${VIRGO_USER} ${VIRGO_URL}/admin/jolokia/search/org.eclipse.virgo.kernel:type=ArtifactModel,*`
	
	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "Virgo response: ${RESULT}"
		echo "-------------------------"
	fi
	
	# extract result
	RESULT=`echo "$RESULT" | grep -oEi "\"value\":\[.*\]" | cut -c 10- | rev | cut -c 2- | rev`
	
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	else
		# format, filter and print result
		FILTER_TYPE=""
		if [ ! -z "${BUNDLE_CUSTOM_TYPE}" ]; then
			FILTER_TYPE="type=${BUNDLE_CUSTOM_TYPE},"
		fi
		FILTER_NAME=""
		if [ ! -z "${BUNDLE_NAME}" ]; then
			FILTER_NAME="name=${BUNDLE_NAME},"
		fi
		FILTER_VERSION=""
		if [ ! -z "${BUNDLE_VERSION}" ]; then
			FILTER_VERSION="version=${BUNDLE_VERSION},"
		fi
	
		echo "$RESULT" | sed -e 's/\",\"/\"\'$'\n\"/g' | awk -F'["=,]' '{ print "name=" $5 ", version=" $11 ", type=" $3 ", region=" $7 }' | grep "${FILTER_TYPE}" | grep "${FILTER_NAME}" | grep "${FILTER_VERSION}"
	fi
	
	;;
############################################
# Execute command: stop, start, uninstall, refresh
stop|start|uninstall|refresh)
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
	RESULT=`curl ${SILENT} -u ${VIRGO_USER} ${VIRGO_URL}/admin/jolokia/exec/org.eclipse.virgo.kernel:artifact-type=${BUNDLE_TYPE},name=${BUNDLE_NAME},region=${BUNDLE_REGION},type=ArtifactModel,version=${BUNDLE_VERSION}/${COMMAND}`

	if [ "${VERBOSE}" = "true" ]; then
		echo "-------------------------"
		echo "Virgo response: ${RESULT}"
		echo "-------------------------"
	fi
	
	# analyze result
	RESULT_STATUS=`echo "$RESULT" | grep -oEi ",\"status\":[0-9]*," | cut -c 11- | rev | cut -c 2- | rev`
	if [ -z "${RESULT}" ]; then
		echo "Failure"
		echo "Details: received empty result"
		exit 2
	elif [ "${RESULT_STATUS}" = "200" ]; then
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
	else
		MESSAGE=`echo "$RESULT" | grep -oPi "\"error\":\".+?\"" | cut -c 10- | rev | cut -c 2- | rev`
		if [ -z "${MESSAGE}" ]; then
			MESSAGE=${RESULT}
		fi
		
		echo "Failure"
		echo "Details: ${MESSAGE}"
		exit 2
	fi
	;;
############################################
# Display help
*)
	if [ "${COMMAND}" != "help" ]; then
		echo "Error: unknown command '${COMMAND}'"
		echo
	fi
	echo "Virgo OSGi bundels management tool. Version ${VERSION}"
	echo
	echo "Usage:"
	echo "  $0 <command> [options]"
	echo
	echo "Commands:"
	echo "  deploy     - upload and deploy OSGi bundle to Virgo server, required options: -f"
	echo "  status     - check status of bundle at Virgo server, required options: -n, -v"
	echo "  stop       - stop bundle at Virgo server, required options: -n, -v"
	echo "  start      - start bundle at Virgo server, required options: -n, -v"
	echo "  refresh    - refresh bundle at Virgo server, required options: -n, -v"
	echo "  uninstall  - uninstall bundle from Virgo server, required options: -n, -v"
	echo "  list       - list bundles deployed at Virgo server, optional filter options: -n, -v, -t"
	echo "  help       - display this help"
	echo
	echo "Options:"
	echo "  -f <path>  - location of OSGi bundle to upload, e.g. /opt/repo/org.slf4j.api-1.7.2.jar"
	echo "  -n <name>  - bundle symbolic name, e.g. org.slf4j.api"
	echo "  -v <ver>   - bundle version, e.g. 1.7.2"
	echo "  -t <type>  - bundle type, possible types: bundle, plan, par, configuration"
	echo "  -user <*>  - user name and password for basic auth, e.g. admin:passwd (will be prompted if not given)"
	echo "  -url <*>   - Virgo server URL, e.g. http://virgo.internal:7070"
	echo "  -verbose   - enable verbose output"
	echo
	echo "Examples:"
	echo "  $0 deploy -f ~/dev/virgo-test-1.0.0-SNAPSHOT.jar"
	echo "  $0 status -n virgo-test -v 1.0.0.SNAPSHOT"
	echo "  $0 stop -n virgo-test -v 1.0.0.SNAPSHOT -url http://localhost:8081"
	echo "  $0 start -n virgo-test -v 1.0.0.SNAPSHOT -verbose"
	echo "  $0 uninstall -n virgo-test -v 1.0.0.SNAPSHOT"
	;;
esac
