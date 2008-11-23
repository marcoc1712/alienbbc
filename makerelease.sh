#!/bin/bash

VERSION71=`sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' Alien/install.xml`
VERSION73=`sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' Alien/install.xml.7_3`
mkdir /tmp/alienbbc_release
mkdir /tmp/alienbbc_release/Alien

# copy everything
cp --preserve=timestamps -Rf Alien/* /tmp/alienbbc_release/Alien

# add Linux specifics + remove windows convert confs
rm /tmp/alienbbc_release/Alien/custom-convert.conf.windows
rm /tmp/alienbbc_release/Alien/custom-convert.conf.windows.7_3
rm /tmp/alienbbc_release/Alien/custom-convert.conf.windows.alt

# remove 7.3 specifics
rm /tmp/alienbbc_release/Alien/RTSP.pm.7_3
rm /tmp/alienbbc_release/Alien/RTSPScanHeaders.pm.7_3
rm /tmp/alienbbc_release/Alien/install.xml.7_3
rm /tmp/alienbbc_release/Alien/custom-convert.conf.7_3

pushd /tmp/alienbbc_release > /dev/null
find /tmp/alienbbc_release -name .svn | xargs rm -Rf
chmod -R a+r *
tar cfz /tmp/alienbbc-linux-v"$VERSION71".tar.gz --numeric-owner --owner=0 --group=0 *
popd > /dev/null
echo "Release available at: /tmp/alienbbc-linux-v"$VERSION71".tar.gz"

# 7.3 specifics
cp --preserve=timestamps Alien/RTSP.pm.7_3 /tmp/alienbbc_release/Alien/RTSP.pm
cp --preserve=timestamps Alien/RTSPScanHeaders.pm.7_3 /tmp/alienbbc_release/Alien/RTSPScanHeaders.pm
cp --preserve=timestamps Alien/install.xml.7_3 /tmp/alienbbc_release/Alien/install.xml
cp --preserve=timestamps Alien/custom-convert.conf.7_3 /tmp/alienbbc_release/Alien/custom-convert.conf

pushd /tmp/alienbbc_release > /dev/null
chmod -R a+r *
chmod +x Alien/Bin/mplayer.sh
tar cfz /tmp/alienbbc-linux-v"$VERSION73".tar.gz --numeric-owner --owner=0 --group=0 *
zip -rq /tmp/alienbbc-linux-v"$VERSION73".zip *
popd > /dev/null
echo "Release available at: /tmp/alienbbc-linux-v"$VERSION73".tar.gz"
echo "Release available at: /tmp/alienbbc-linux-v"$VERSION73".zip"

# remove linux specifics and copy windows versions
rm -f /tmp/alienbbc_release/*.conf
rm -f /tmp/alienbbc_release/Alien/Bin/mplayer.sh

# 7.1/7.2 specifics
cp --preserve=timestamps Alien/RTSP.pm /tmp/alienbbc_release/Alien/RTSP.pm
cp --preserve=timestamps Alien/RTSPScanHeaders.pm /tmp/alienbbc_release/Alien/RTSPScanHeaders.pm
cp --preserve=timestamps Alien/install.xml /tmp/alienbbc_release/Alien/install.xml
cp --preserve=timestamps Alien/custom-convert.conf.windows /tmp/alienbbc_release/Alien/custom-convert.conf
cp --preserve=timestamps Alien/custom-convert.conf.windows.alt /tmp/alienbbc_release/Alien/custom-convert.conf.alt

pushd /tmp/alienbbc_release > /dev/null
chmod -R a+r *
zip -rq /tmp/alienbbc-windows-v"$VERSION71".zip *
popd > /dev/null
echo "Release available at: /tmp/alienbbc-windows-v"$VERSION71".zip"

# 7.3 specifics
cp --preserve=timestamps Alien/RTSP.pm.7_3 /tmp/alienbbc_release/Alien/RTSP.pm
cp --preserve=timestamps Alien/RTSPScanHeaders.pm.7_3 /tmp/alienbbc_release/Alien/RTSPScanHeaders.pm
cp --preserve=timestamps Alien/install.xml.7_3 /tmp/alienbbc_release/Alien/install.xml
cp --preserve=timestamps Alien/custom-convert.conf.windows.7_3 /tmp/alienbbc_release/Alien/custom-convert.conf

pushd /tmp/alienbbc_release > /dev/null
chmod -R a+r *
zip -rq /tmp/alienbbc-windows-v"$VERSION73".zip *
popd > /dev/null
echo "Release available at: /tmp/alienbbc-windows-v"$VERSION73".zip"

rm -Rf /tmp/alienbbc_release
