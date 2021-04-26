#!/bin/sh

set -e

if [ "$AWS_DEBUG" ]; then
	set -x
fi

DIR="$(readlink -f "$(dirname "$0")")"

REGION=$1
BUCKET=$2
REMOTE=$3
LOCALS=$4

if [ $# -ge 4 ]; then
	shift 4
else
	shift $#
fi

exec $DIR/aws-s3.sh "" "${REGION}" "${BUCKET}" "${REMOTE}" "" -o "${LOCALS}" "$@"
