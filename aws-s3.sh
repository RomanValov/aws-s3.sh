#!/bin/sh

set -e

if [ "$AWS_DEBUG" ]; then
	set -x
fi

METHOD="${1:-}"
REGION="${2:-}"
BUCKET="${3:-}"
URL="${4:-}"
PARAMS="${5:-}"

if [ $# -ge 5 ]; then
	shift 5
else
	shift $#
fi

echo='/bin/echo -e -n'

s3access=${S3_ACCESS_KEY:?}
s3secret=${S3_SECRET_KEY:?}

meth="${METHOD:-GET}"
host='s3.amazonaws.com'
host="${BUCKET:+$BUCKET.}s3.${REGION:+$REGION.}amazonaws.com"
hreg="${REGION:-us-east-1}"
_uri="$URL"
qstr="${PARAMS}"

date=`date -u +%Y%m%dT%H%M%SZ`
#date=`date -u -Is`
dday=`${echo} ${date} | cut -c-8`

hash="`${echo} | openssl dgst -sha256 -r | cut -f1 -d ' '`"
hdrs="host;x-amz-content-sha256;x-amz-date"
creq="${meth}\n/${_uri}\n${qstr}\nhost:${host}\nx-amz-content-sha256:${hash}\nx-amz-date:${date}\n\n${hdrs}\n${hash}"

sreq="${dday}/${hreg}/s3/aws4_request"
stos="AWS4-HMAC-SHA256\n${date}\n${sreq}\n`${echo} "${creq}" | openssl dgst -sha256 -r | cut -f1 -d' '`"

skey="`${echo} "${dday}" | openssl dgst -sha256 -mac HMAC -macopt "key:AWS4${s3secret}" -r | cut -f1 -d' '`"
skey="`${echo} "${hreg}" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${skey}" -r | cut -f1 -d' '`"
skey="`${echo} "s3" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${skey}" -r | cut -f1 -d' '`"
skey="`${echo} "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${skey}" -r | cut -f1 -d' '`"

sign="`${echo} -e -n "${stos}" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:${skey}" -r | cut -f1 -d' '`"

if [ "${AWS_DEBUG}" ]; then
	DEBUGOPT=-v
else
	DEBUGOPT=-f
fi

exec curl "https://${host}/${_uri}${qstr:+?${qstr}}" -X "${meth}" -H "@-" -L -J ${DEBUGOPT} "$@" <<- EOF
	Host: ${host}
	x-amz-date: ${date}
	x-amz-content-sha256: ${hash}
	Authorization: AWS4-HMAC-SHA256 Credential=${s3access}/${sreq},SignedHeaders=${hdrs},Signature=${sign}
EOF
