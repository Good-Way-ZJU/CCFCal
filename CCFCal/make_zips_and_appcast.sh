#!/bin/sh

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# If CCFCal.app is not found on the Desktop, quit.
APP_PATH="${HOME}/Desktop/CCFCal.app"
if [ ! -d "${APP_PATH}" ]
then
    echo "\n"
    echo "  + ${RED}NOT FOUND:${NC} ${APP_PATH}"
    echo "  + Export notarized CCFCal.app to Desktop."
    echo "  + See ../CONTRIBUTING.md for release build instructions."
    echo "\n"
    exit 1
fi

# Get the bundle version from the plist.
PLIST_FILE="${APP_PATH}/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ${PLIST_FILE})
SHORT_VERSION_STRING=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ${PLIST_FILE})

# Set up file names and paths.
ZIP_NAME="CCFCal-${SHORT_VERSION_STRING}.zip"
ZIP_NAME=${ZIP_NAME// /-}
DEST_DIR="${HOME}/Desktop/CCFCal-${SHORT_VERSION_STRING}"
XML_PATH="${DEST_DIR}/ccfcal.xml"
ZIP_PATH1="${DEST_DIR}/${ZIP_NAME}"
ZIP_PATH2="${DEST_DIR}/CCFCal.zip"

# Run some diagnostics so we can see all is ok."
echo ""
( set -x; spctl -vvv --assess --type exec ${APP_PATH} )
echo ""
( set -x; codesign -vvv --deep --strict ${APP_PATH} )
echo ""
( set -x; codesign -dvv ${APP_PATH} )

echo ""
echo "Making zips and appcast for ${GREEN}${SHORT_VERSION_STRING} (${VERSION})${NC}..."

# Make output dir (if necessary) and clear its contents.
rm -frd "${DEST_DIR}"
mkdir -p "${DEST_DIR}"

# Compress CCFCal.app and make a copy without version suffix.
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH1}"
cp "${ZIP_PATH1}" "${ZIP_PATH2}"

# Get EdDSA signature (with private key in Keychain) and file size.
EDDSA_AND_FILESIZE=$(../Sparkle-1.27.1/bin/sign_update "${ZIP_PATH1}")

# On error, sign_update returns a message starting with "ERROR".
if [[ ${EDDSA_AND_FILESIZE} == ERROR* ]]
then
    echo
    echo "${RED}${EDDSA_AND_FILESIZE}${NC}"
    echo
    exit 1
fi

DATE=$(TZ=GMT date)

# Make the Sparkle appcast XML file.
cat > "${XML_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss
    version="2.0"
    xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
    xmlns:dc="http://purl.org/dc/elements/1.1/" >
  <channel>
    <title>CCFCal Release Notes</title>
    <link>https://good-way-zju.github.io/CCFCal/ccfcal.xml</link>
    <description>Most recent changes</description>
    <language>en</language>
    <item>
      <title>Version ${SHORT_VERSION_STRING}</title>
      <sparkle:minimumSystemVersion>11.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://good-way-zju.github.io/CCFCal/releasenotes.html</sparkle:releaseNotesLink>
      <pubDate>${DATE} +0000</pubDate>
      <enclosure
          url="https://good-way-zju.github.io/CCFCal/${ZIP_NAME}"
          ${EDDSA_AND_FILESIZE}
          sparkle:version="${VERSION}"
          sparkle:shortVersionString="${SHORT_VERSION_STRING}"
          type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Done!"
echo ""

open -R "${DEST_DIR}/ccfcal.xml"
