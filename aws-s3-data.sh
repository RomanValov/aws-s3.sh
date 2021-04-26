#!/bin/sh

set -e

curl_ () {
	curl -Gso /dev/null -w "%{url_effective}" --data-urlencode "$*" '' | cut -c3-
}

more=

echo='/bin/echo -e -n'

while [ $# -gt 0 ]; do
	name=$1
	data=$2

	if [ $# -ge 2 ]; then
		shift 2
	else
		shift 1
	fi

	name="`${echo} "${name}" | curl_ @-`"
	data="`${echo} "${data}" | curl_ @-`"

	echo "${name}=${data}"
done | sort | xargs -rx | tr -s ' ' '&'
