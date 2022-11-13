#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Remove Magisk Scripts
rm -rf /data/adb/post-fs-data.d/service.sh
rm -rf /data/adb/service.d/modprobe.sh
rm -rf /data/adb/service.d/module.sh
rm -rf /data/adb/service.d/runtime.sh
# Magisk Current Base Folder
MIRROR="$(magisk --path)/.magisk/mirror"
# Mount actual partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /product > /dev/null 2>&1
mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
# Mount mirror partitions
mount -o remount,rw,errors=continue $MIRROR/system_root 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/system 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/product 2>/dev/null
mount -o remount,rw,errors=continue $MIRROR/system_ext 2>/dev/null
# Set installation layout
SYSTEM="$MIRROR/system"
# Current Base Folder
test -d "$MIRROR" || SYSTEM='/system'
# Remove Google Mobile Services
rm -rf $SYSTEM/app/FaceLock
rm -rf $SYSTEM/app/GoogleCalendarSyncAdapter
rm -rf $SYSTEM/app/GoogleContactsSyncAdapter
rm -rf $SYSTEM/priv-app/ConfigUpdater
rm -rf $SYSTEM/priv-app/GmsCoreSetupPrebuilt
rm -rf $SYSTEM/priv-app/GoogleLoginService
rm -rf $SYSTEM/priv-app/GoogleServicesFramework
rm -rf $SYSTEM/priv-app/Phonesky
rm -rf $SYSTEM/priv-app/PrebuiltGmsCore
rm -rf $SYSTEM/etc/default-permissions/default-permissions.xml
rm -rf $SYSTEM/etc/default-permissions/gapps-permission.xml
rm -rf $SYSTEM/etc/permissions/com.google.android.dialer.support.xml
rm -rf $SYSTEM/etc/permissions/com.google.android.maps.xml
rm -rf $SYSTEM/etc/permissions/privapp-permissions-google.xml
rm -rf $SYSTEM/etc/permissions/split-permissions-google.xml
rm -rf $SYSTEM/etc/preferred-apps/google.xml
rm -rf $SYSTEM/etc/sysconfig/google.xml
rm -rf $SYSTEM/etc/sysconfig/google_build.xml
rm -rf $SYSTEM/etc/sysconfig/google_exclusives_enable.xml
rm -rf $SYSTEM/etc/sysconfig/google-hiddenapi-package-whitelist.xml
rm -rf $SYSTEM/etc/sysconfig/google-rollback-package-whitelist.xml
rm -rf $SYSTEM/etc/sysconfig/google-staged-installer-whitelist.xml
rm -rf $SYSTEM/etc/security/fsverity/gms_fsverity_cert.der
rm -rf $SYSTEM/etc/security/fsverity/play_store_fsi_cert.der
rm -rf $SYSTEM/framework/com.google.android.dialer.support.jar
rm -rf $SYSTEM/framework/com.google.android.maps.jar
rm -rf $SYSTEM/product/overlay/PlayStoreOverlay.apk
# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*
# Purge runtime permissions
rm -rf $(find /data -iname "runtime-permissions.xml")
# Remove BiTGApps Module
rm -rf /data/adb/modules/BiTGApps
