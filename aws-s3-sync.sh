#!/bin/sh

set -e

if [ "$AWS_DEBUG" ]; then
	set -x
fi

DIR="$(readlink -f "$(dirname "$0")")"

REGION=$1
BUCKET=$2
REMOTE=${3%%/}/
LOCALS=${4%%/}/

if [ $# -ge 4 ]; then
	shift 4
else
	shift $#
fi

path="$REMOTE"

orig="$LOCALS"
sync="$LOCALS.sync"

rm -rf "$sync"
mkdir -p "$orig" "$sync"

for file in `ls -1 "$orig"`; do
	touch "$sync/$file"
done

more='true'

while [ "$more" ] && "$more"; do
	if [ "${next}" ]; then
		next="continuation-token ${next}"
	fi

	qstr="`$DIR/aws-s3-data.sh list-type 2 prefix "${path}" delimiter / ${next}`"

	list="`$DIR/aws-s3.sh "" "${REGION}" "${BUCKET}" "" "${qstr}"`"
	list="${list:?}"

	echo "$list" | tr -d '\n' | hxselect -s'\n' 'ListBucketResult>Contents' | while read elem; do
		name=`echo "$elem" | hxselect -c 'Key'`
		file=${name##${path}}

		etag=`echo "$elem" | hxselect -c 'ETag'`

		if [ -z "$file" ] || [ "$name" = "$file" ]; then
			continue
		fi

		if echo "$file" | grep -q '/'; then
			continue
		fi

		r_dt=`echo "$elem" | hxselect -c 'LastModified'`
		r_dt=`echo -n "$r_dt" | date -uf - +%s`

		l_dt=`date -ur "$orig/$file" -Is 2>/dev/null || :`
		l_dt=`echo -n "$l_dt" | date -uf - +%s`

		r_sz=`echo "$elem" | hxselect -c 'Size'`
		l_sz=`wc -c "$orig/$file" 2>/dev/null | cut -f1 -d' '`

		echo
		echo "Filename: $file"

		if [ -z "$l_dt" ] || [ -z "$r_dt" ] || [ "${l_sz:-0}" -gt "$r_sz" ]; then
			echo "Remote size: $r_sz"
			echo " Local size: $l_sz"
			echo "Downloading..."
			echo
			$DIR/aws-s3.sh "" "${REGION}" "${BUCKET}" "$name" "" "$@" -o "$sync/$file"
			mv -f "$sync/$file" "$orig/$file"
		elif [ "$l_dt" -ne "$r_dt" ]; then
			echo "Remote date: `date -d @$r_dt -Is`"
			echo " Local date: `date -d @$l_dt -Is`"
			echo "Downloading..."
			echo
			$DIR/aws-s3.sh "" "${REGION}" "${BUCKET}" "$name" "" "$@" -o "$sync/$file"
			mv -f "$sync/$file" "$orig/$file"
		elif  [ "$l_sz" -lt "$r_sz" ]; then
			echo "Remote size: $r_sz"
			echo " Local size: $l_sz"
			echo "Continueing..."
			echo
			$DIR/aws-s3.sh "" "${REGION}" "${BUCKET}" "$name" "" "$@" -o "$orig/$file" -C -
			rm -f "$sync/$file"
		else
			echo "Skipping..."
			echo
			rm -f "$sync/$file"
		fi

		touch -d @$r_dt "$orig/$file"
	done

	next=`echo "$list" | hxselect -c 'NextContinuationToken'`
	more=`echo "$list" | hxselect -c 'IsTruncated'`
done

for file in `ls -1 "$sync"`; do
	echo
	echo "Filename: $file"
	echo "NotFound..."
	echo

	rm -f "$sync/$file"
	rm -f "$orig/$file"
done

rmdir "$sync"
