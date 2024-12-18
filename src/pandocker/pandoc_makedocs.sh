#!/bin/bash

set -eo pipefail

# Input variables
FOLDER=${1:-Document}
SCSTG_VERSION=${2:-SNAPSHOT}
SCSVS_VERSION=${3:-SNAPSHOT}

rm -rf build
cp -R $FOLDER "build"

# You can also use the environment variables below to adapt the build process
IMG=${IMG:-dalibo/pandocker}
TAG=${TAG:-23.03} # /!\ use stable-full for non-european languages
LATEX_TEMPLATE=${LATEX_TEMPLATE:-eisvogel}
TITLE=${TITLE:-OWASP Smart Contract Security Testing Guide ${SCSTG_VERSION}}

PANDOC_PARAMS=${PANDOC_PARAMS:-}
PANDOC_PARAMS+="--resource-path=.:build "
PANDOC_PARAMS+="--metadata scstg_version=${SCSTG_VERSION} --metadata scsvs_version=${SCSVS_VERSION}"

[ ! -z "${VERBOSE}" ] && PANDOC_PARAMS+="--verbose "

PANDOCKER="docker run --rm --volume `pwd`:/pandoc ${IMG}:${TAG} ${PANDOC_PARAMS}"

# remove the HTML comment from \pagebreak
docker run --rm --entrypoint '/bin/sh' --volume `pwd`:/pandoc ${IMG}:${TAG} -c 'sed -i "s#<!-- \(.*\) -->#\1#g" build/*.md'

# convert HTML images to pandoc markdown images
docker run --rm --entrypoint '/bin/sh' --volume `pwd`:/pandoc ${IMG}:${TAG} -c 'sed -i -f src/pandocker/imagereplace.sed build/0x*.md'

# Use pandocker PANDOCKER by default, unless `export PANDOC=pandoc`
# this is useful for CI, because we can run the script directly inside the container
PANDOC=${PANDOC:-${PANDOCKER}}

METADATA="build/metadata.md"
CHAPTERS="build/0x*.md"
OUTPUT_BASE_NAME="OWASP_SCSTG"

[ ! -z "${VERBOSE}" ] && echo "[*] Creating PDF"

# header
${PANDOC} \
  --output tmp_latex-header.latex \
  --template src/pandocker/latex-header.tex \
  ${METADATA}

# cover
${PANDOC} \
  --output tmp_cover.latex \
  --template src/pandocker/cover.tex \
  ${METADATA}

# first_page
${PANDOC} \
  --output tmp_first_page.latex \
  --template src/pandocker/first_page.tex \
  ${METADATA}

# PDF
${PANDOC} \
  --template=${LATEX_TEMPLATE} \
  --pdf-engine=xelatex \
  --columns 50 \
  --highlight-style=tango \
  --metadata title="${TITLE}" \
  --include-in-header tmp_latex-header.latex \
  --include-before-body tmp_cover.latex \
  --include-before-body tmp_first_page.latex \
  --output ${OUTPUT_BASE_NAME}.pdf \
  -V fontsize=10pt \
  ${METADATA} \
  ${CHAPTERS}

# EPUB
echo "[*] Creating epub"

${PANDOC} \
  --metadata title="${TITLE}" \
  --metadata author="Shashank, Pratik Lagaskar and Nehal Pillai" \
  --epub-cover-image=cover.png \
  -o ${OUTPUT_BASE_NAME}.epub \
  ${METADATA} \
  ${CHAPTERS}

# clean temp files
rm -f tmp_latex-header.latex tmp_cover.latex tmp_first_page.latex
rm -rf build