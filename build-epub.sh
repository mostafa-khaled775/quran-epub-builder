#!/bin/bash

# Define cache directory and base URL
CACHE_DIR=".quran_cache"  # Hidden directory in the current directory
BASE_URL="https://download.qurancomplex.gov.sa/resources_dev/"
AMIRI_URL="https://github.com/aliftype/amiri/releases/download/1.000/Amiri-1.000.zip"  
AMIRI_SHA1="818dfe4198d4d981e2d040fefc1c4b37f3f6ef5d"
SCHEHERAZADE_NEW_URL="https://software.sil.org/downloads/r/scheherazade/ScheherazadeNew-4.000.zip"
SCHEHERAZADE_NEW_SHA1="9c4496b98204e66549df8fdb0166c653d9324080"

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
  local url=$1
  local file=$2
  local sha1_expected=$3

  mkdir -p "$CACHE_DIR"

  if [ -f "$file" ]; then
    echo "File $file already exists." >&2
  else
    echo "Downloading $file..." >&2
    curl -sSL --output "$file" "$url"
  fi

  echo "Verifying SHA-1 checksum..." >&2
  local sha1_actual=$(sha1sum "$file" | awk '{ print $1 }')

  if [ "$sha1_actual" = "$sha1_expected" ]; then
    echo "SHA-1 checksum matches." >&2
  else
    echo "SHA-1 checksum does not match. Download might be corrupted." >&2
    echo expected: "$sha1_expected" >&2
    echo found: "$sha1_actual" >&2
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

  echo "Extracting $json_file from $zip_path..." >&2
  unzip -o -j "$zip_path" "$json_file" -d "$CACHE_DIR" >/dev/null
  echo "Extracting $ttf_file from $zip_path..." >&2
  unzip -o -j "$zip_path" "$ttf_file" -d "$CACHE_DIR" >/dev/null

  json_file="$CACHE_DIR/$(basename "$json_file")"
  ttf_file="$CACHE_DIR/$(basename "$ttf_file")"

  echo "$json_file:$ttf_file"
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
mkdir -p "$EPUB"/{styles,fonts,text,images}

FONT_FAMILY=$(fc-query -f '%{family[0]}\n' "$TTF_FILE")
TOC_XHTML=$(jq --from-file jq/build-toc-xhtml.jq -r < "$JSON_FILE")
TOC_NCX=$(jq --from-file jq/build-toc-ncx.jq -r < "$JSON_FILE")
QURAN_XHTML=$(jq --from-file jq/build-quran-xhtml.jq -r < "$JSON_FILE")

cp "$TTF_FILE" "$EPUB/fonts/"

download_and_verify "$AMIRI_URL" "$CACHE_DIR/Amiri.zip" "$AMIRI_SHA1"
if [ $? -ne 0 ]; then
  exit 1
fi
unzip -o -j "$CACHE_DIR/Amiri.zip" Amiri-1.000/Amiri-Regular.ttf -d "$CACHE_DIR" >/dev/null
cp "$CACHE_DIR/Amiri-Regular.ttf" "$EPUB/fonts/"

download_and_verify "$SCHEHERAZADE_NEW_URL" "$CACHE_DIR/scheherazade-new.zip" "$SCHEHERAZADE_NEW_SHA1"
if [ $? -ne 0 ]; then
  exit 1
fi
unzip -o -j "$CACHE_DIR/scheherazade-new.zip" ScheherazadeNew-4.000/ScheherazadeNew-Regular.ttf -d "$CACHE_DIR" >/dev/null
cp "$CACHE_DIR/ScheherazadeNew-Regular.ttf" "$EPUB/fonts/"


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

download_and_verify "$BASE_URL/${NARRATION_ZIP_FILES[$narration]}" "$CACHE_DIR/${NARRATION_ZIP_FILES[$narration]}" "${NARRATION_SHA1[$narration]}"
if [ $? -ne 0 ]; then
  exit 1
fi

extracted_files=$(extract_files "$narration")
if [ $? -ne 0 ]; then
  exit 1
fi

json_file=${extracted_files%:*}
ttf_file=${extracted_files##*:}

echo "Running builder script..."
build-epub "$json_file" "$ttf_file" "Quran ($narration)"
