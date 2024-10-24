#!/bin/bash

set -e

SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


if [[ $# -ne 2 && $# -ne 3 ]]; then
	echo "usage: $0 SOURCE_FOLDER DESTINATION_FOLDER NOTTOPLEVEL"
	echo "       NOTTOPLEVEL marks a not top level folder it is not an empty string."
	exit 1
fi


SOURCE_FOLDER=$1
DESTINATION_FOLDER=$2
NOTTOPLEVEL=$3
TMP_INDEX=${DESTINATION_FOLDER}/index.md
MARKDOWN="pandoc --from markdown --to html5 --section-divs --mathml --toc --toc-depth=1 -c /style.css --template=${SCRIPT_DIR}/template.html"


# check that pandoc is installed
hash pandoc 2>/dev/null || { echo >&2 "I require 'pandoc' but it's not installed.  Aborting."; exit 1; }


# empty destination folder
mkdir -p "${DESTINATION_FOLDER}"
rm -rf "${DESTINATION_FOLDER}/"*

# check if index file available
INDEX_MD=${SOURCE_FOLDER}/index.md
if [ ! -f "${INDEX_MD}" ]; then
	if [ "${NOTTOPLEVEL}" != "ntl" ]; then
		echo "no index.md in ${SOURCE_FOLDER}"
		exit 1
	else
		INDEX_MD=${SCRIPT_DIR}/index.md
	fi
fi

# prepare temporary index file for content links if any md files
cp "${INDEX_MD}" "${TMP_INDEX}"
num_md=`ls -al "${SOURCE_FOLDER}/"*.md | grep -c md`
if [ $num_md -gt 1 ]; then
	printf "\n\n# Articles\n\n" >> ${TMP_INDEX}
fi

# start processing
echo "${SOURCE_FOLDER}"

# iterate over markdown files in subdirectory
for file in "${SOURCE_FOLDER}/"*.md
do
	# extract file name without path
	file=${file##*/}

	# do not process index file
	if [ ${file} == index.md ]; then
		continue
	fi

	# notify processed file
	echo "  ${file}"

	# prepare paths
	SOURCE_FILE=${SOURCE_FOLDER}/${file}
	DEST_FILE=${DESTINATION_FOLDER}/${file%.*}.html
	FILE_NAME=${file%.*}
	FILE_LINK=./${FILE_NAME}.html

	# do processing
	${MARKDOWN} --variable backtoindex "${SOURCE_FILE}" >> "${DEST_FILE}"

	# insert entry in index file
	printf "* [${FILE_NAME}](${FILE_LINK})\n" >> "${TMP_INDEX}"
done

# copy all other files than .md
find "${SOURCE_FOLDER}" -maxdepth 1 -type f -not -name "*.md" -not -name "*.sql" -not -name "*.xml" -exec cp {} "${DESTINATION_FOLDER}" \;
find "${SOURCE_FOLDER}" -maxdepth 1 -type d -name "_Assets" -exec cp -r {} "${DESTINATION_FOLDER}" \;

# prepare index file for sub dir links if any
num_child=`ls -al "${SOURCE_FOLDER}" | grep -c ^d`
if [ $num_child -gt 2 ] && [ "${NOTTOPLEVEL}" != "ntl" ]; then
	printf "\n\n# Customers\n\n" >> "${TMP_INDEX}"
fi

# iterate over all sub directories with index file
for sub in "${SOURCE_FOLDER}/"*/
do
	# extract file name without path
	sub=$(basename "${sub}")
	if [ "${sub}" = "*" ]; then
		continue
	fi

	SOURCE_SUB=${SOURCE_FOLDER}/${sub}
	DEST_SUB=${DESTINATION_FOLDER}/${sub}

	# check if there is any md file
	count=`ls -1 "${SOURCE_SUB}/"*.md 2>/dev/null | wc -l`
	if [ $count == 0 ]; then
		continue
	fi

	# insert entry in index file
	printf "* [${sub}](./${sub}/index.html)\n" >> "${TMP_INDEX}"

	# recursive process sub folders
	$0 "${SOURCE_SUB}" "${DEST_SUB}" "ntl"
done

# define if this is the top level index which needs not back link
TOPTOINDEX=""
if [ ! -z ${NOTTOPLEVEL} ]; then
	TOPTOINDEX="--variable totopindex"
fi

# process temporary index file
${MARKDOWN} ${TOPTOINDEX} "${TMP_INDEX}" >> "${DESTINATION_FOLDER}/index.html"
#rm ${TMP_INDEX}

# copy in style
if [ "${NOTTOPLEVEL}" != "ntl" ]; then
	cp ${SCRIPT_DIR}/style.css "${DESTINATION_FOLDER}"
	cp ${SCRIPT_DIR}/back.png "${DESTINATION_FOLDER}"
fi