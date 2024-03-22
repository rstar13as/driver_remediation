#!/bin/sh

#  driver_remediation.sh
#
#  Remediates a stuck system extension.
#  KB: https://community.carbonblack.com/t5/Knowledge-Base/Carbon-Black-Cloud-Unable-to-upgrade-or-install-due-to-existing/ta-p/102960
#  Copyright © 2022 VMware. All rights reserved.

dir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
cd "$dir" || exit

UNINSTALL=0
KB_URL="https://community.carbonblack.com/t5/Knowledge-Base/Carbon-Black-Cloud-Unable-to-upgrade-or-install-due-to-existing/ta-p/102960" # Update this as needed

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi


while [ $# -gt 0 ]; do
    case $1 in
        -u|--uninstall)
         UNINSTALL=1
        shift
         ;;
        -h|--help)
         echo "-u --uninstall : Cleans up sensor files for a full removal of the CBC sensor. Do not use if upgrading."
         echo "-h --help : Shows this message."
         exit 0
         ;;
        -*|--*)
         echo "Unknown option $1"
         exit 1
         ;;
    esac
done


# get running systext version
TARGET="$(systemextensionsctl list | grep 'com\.vmware\.carbonblack\.cloud\.se-agent\.extension[[:space:]]*\[activated[[:space:]]*enabled\]')"

if [ -z "$TARGET" ];
then
    echo "Active system extension not detected. No remediation required. Exiting."
    exit 0
else
    VERSION="$(echo "$TARGET" | grep -o '[[:digit:]]\.[[:digit:]]\.[[:digit:]]fc[[:digit:]]*/' | awk -F '/' '{ print $1 }')"
    echo "Active system extension (version: ${VERSION}) detected. Proceeding with remediation."
fi

if [ -d "/Applications/VMware CBCloud.app" ]; # need to clean up any previous version hanging around
then
    echo "Cleaning up previous instance of tool."
    rm -rf /Applications/VMware\ CBCloud.app
fi

if [ ! -d "./VMware CBCloud-${VERSION}.app" ];
then
    echo "Remediation bundle for sensor version ${VERSION} not found."
    echo "Please check KB ${KB_URL} for the latest version of this tool to handle sensor version ${VERSION}."
    exit 2
fi

codesign -v "./VMware CBCloud-${VERSION}.app"
ret=$?
if [ "$ret" -ne 0 ];
then
    echo "Remediation bundle is improperly signed. Please check the KB ${KB_URL} for the latest version of this tool. Codesign error ${ret}"
    exit 3
fi

# copy affected version to /Applications
cp -R "./VMware CBCloud-${VERSION}.app" "/Applications/VMware CBCloud.app"
ret=$?
if [ "$ret" -ne 0 ];
then
    echo "Failure copying system extension bundle to destination. Error: ${ret}"
    exit 4
fi

/Applications/VMware\ CBCloud.app/Contents/MacOS/VMware\ CBCloud -u
ret=$?
if [ "$ret" -ne 0 ];
then
    echo "Failure calling system extension unload. Error: ${ret}"
    exit 5
fi

rm -rf "/Applications/VMware CBCloud.app"

TARGET="$(systemextensionsctl list | grep 'com\.vmware\.carbonblack\.cloud\.se-agent\.extension[[:space:]]*\[terminated.*')"

if [ -z "$TARGET" ];
then
    echo "Unable to successfully remediate."
    exit 6
else
    echo "System extension successfully removed."
fi


if [ "$UNINSTALL" -eq 1 ];
then
    rm -rf /Library/Application\ Support/com.vmware.carbonblack.cloud/
    rm -rf /Library/LaunchDaemons/com.vmware.carbonblack.cloud.daemon.plist
    rm -rf /Library/LaunchAgents/com.vmware.carbonblack.cloud.ui.plist
fi

exit 0

# done
