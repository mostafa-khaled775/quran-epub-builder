#!/bin/bash

# Define cache directory and base URL
CACHE_DIR=".quran_cache"  # Hidden directory in the current directory
BASE_URL="https://download.qurancomplex.gov.sa/resources_dev/"


# Define narration to zip file name mapping (associative array)
declare -A NARRATION_ZIP_FILES=(
  ["Hafs"]="UthmanicHafs_v2-0.zip"
  ["Warsh"]="UthmanicWarsh_v2-1.zip"
  ["Shubah"]="UthmanicShuba_v2-0.zip"
  ["Qaloun"]="UthmanicQaloun_v2-1.zip"
  ["Duri"]="UthmanicDouri_v2-0.zip"
  ["Susi"]="UthmanicSousi_v2-0.zip"
)

# Define SHA-1 lookup table (associative array)
declare -A NARRATION_SHA1=(
  ["Hafs"]="36ea5ab0d7ea1702f17ff43f9b50924cccd77ebf"
  ["Warsh"]="44ecea8feb23817fdc01a8ee2162a6a0cf08cae7"
  ["Shubah"]="8d66bdf0cab96dc7d1032792c19f77980ca6682a"
  ["Qaloun"]="81733666be17742e13c9fa4c7d26d42b1adc67c8"
  ["Duri"]="8049482f04b4ff1053a7859f96b2b113b9771efb"
  ["Susi"]="e52dbc6d8b43797a8faa0fd1ec1d8e5000265674"
)


# Function to download and verify the zip file
download_and_verify() {
  local narration=$1
  local zip_file="${NARRATION_ZIP_FILES[$narration]}"
  local sha1_expected="${NARRATION_SHA1[$narration]}"
  local zip_path="$CACHE_DIR/$zip_file"

  mkdir -p "$CACHE_DIR"

  if [ -f "$zip_path" ]; then
    echo "File $zip_path already exists."
  else
    echo "Downloading $zip_file..."
    curl -sSL --output "$zip_path" "$BASE_URL/$zip_file"
  fi

  echo "Verifying SHA-1 checksum..."
  local sha1_actual=$(sha1sum "$zip_path" | awk '{ print $1 }')

  if [ "$sha1_actual" = "$sha1_expected" ]; then
    echo "SHA-1 checksum matches."
  else
    echo "SHA-1 checksum does not match. Download might be corrupted."
    echo expected: "$sha1_expected"
    echo found: "$sha1_actual"
    return 1
  fi
}

# Function to extract files from the zip archive
extract_files() {
  local narration=$1
  local zip_file="${NARRATION_ZIP_FILES[$narration]}"
  local zip_path="$CACHE_DIR/$zip_file"
  
  local json_file
  local ttf_file

  readarray -t files < <(unzip -Z1 "$zip_path")

  for file in "${files[@]}"; do
    if [[ "$file" == *.json ]]; then
      json_file="$file"
    elif [[ "$file" == *.ttf ]]; then
      ttf_file="$file"
    fi
  done

  echo "Extracting $json_file from $zip_path..."
  unzip -o -j "$zip_path" "$json_file" -d "$CACHE_DIR" >/dev/null
  echo "Extracting $ttf_file from $zip_path..."
  unzip -o -j "$zip_path" "$ttf_file" -d "$CACHE_DIR" >/dev/null

  json_file="$CACHE_DIR/$(basename "$json_file")"
  ttf_file="$CACHE_DIR/$(basename "$ttf_file")"

  echo "Running builder script..."
  build-epub "$json_file" "$ttf_file" "Quran ($narration)"
}

build-epub() {

JSON_FILE="$1"
TTF_FILE="$2"
TITLE="$3"

EBOOK="$CACHE_DIR/$TITLE"
META="$EBOOK/META-INF"
EPUB="$EBOOK/EPUB"

mkdir -p "$EBOOK"
mkdir -p "$META"
mkdir -p "$EPUB"/{styles,fonts,text}

FONT_FAMILY=$(fc-query -f '%{family[0]}\n' "$TTF_FILE")
TOC_XHTML=$(jq --from-file jq/build-toc-xhtml.jq -r < "$JSON_FILE")
TOC_NCX=$(jq --from-file jq/build-toc-ncx.jq -r < "$JSON_FILE")
QURAN_XHTML=$(jq --from-file jq/build-quran-xhtml.jq -r < "$JSON_FILE")

cp "$TTF_FILE" "$EPUB/fonts/"

template() {
  file=$1
  shift
  eval "$(printf 'local %s\n' "$@")
cat <<EOF
$(cat "templates/$file")
EOF"
}


template mimetype > "$EBOOK/mimetype"
template container.xml > "$META/container.xml"
template com.apple.ibooks.display-options.xml > "$META/com.apple.ibooks.display-options.xml"
template stylesheet.css > "$EPUB/styles/stylesheet.css"
template nav.xhtml > "$EPUB/nav.xhtml"
template toc.ncx > "$EPUB/toc.ncx"
template content.opf > "$EPUB/content.opf"
template title_page.xhtml > "$EPUB/text/title_page.xhtml"
template quran.xhtml > "$EPUB/text/quran.xhtml"


pushd "$EBOOK" >/dev/null || exit 1
zip -r "$TITLE.epub" "./" >/dev/null
popd >/dev/null || return
mv "$EBOOK/$TITLE.epub" ./

echo "successfully built $TITLE.epub!"
}

# Parse command line arguments
narration="Hafs"  # Default narration
while getopts "n:" opt; do
  case $opt in
    n)
      narration=$OPTARG
      ;;
    *)
      echo "Usage: $0 [-n <narration>]"
      exit 1
      ;;
  esac
done

# Ensure narration is valid
if [ -z "${NARRATION_ZIP_FILES[$narration]}" ]; then
  echo "Invalid narration specified."
  echo "Valid narrations are: ${!NARRATION_ZIP_FILES[*]}"
  exit 1
fi

# Create cache directory if it doesn't exist
if [ ! -d "$CACHE_DIR" ]; then
  mkdir -p "$CACHE_DIR"
fi

download_and_verify "$narration"

# Check for download error (exit if curl fails)
if [ $? -ne 0 ]; then
  exit 1
fi

extract_files "$narration"
