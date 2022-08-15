#!/system/bin/sh
#
# This file is part of The BiTGApps Project

# Remove BiTGApps Module
rm -rf /data/adb/modules/BiTGApps
# Remove Magisk Scripts
rm -rf /data/adb/post-fs-data.d/service.sh
rm -rf /data/adb/service.d/modprobe.sh
# Mount partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /product > /dev/null 2>&1
# Remove Google Mobile Services
rm -rf /system/app/FaceLock
rm -rf /system/app/GoogleCalendarSyncAdapter
rm -rf /system/app/GoogleContactsSyncAdapter
rm -rf /system/priv-app/ConfigUpdater
rm -rf /system/priv-app/GmsCoreSetupPrebuilt
rm -rf /system/priv-app/GoogleLoginService
rm -rf /system/priv-app/GoogleServicesFramework
rm -rf /system/priv-app/Phonesky
rm -rf /system/priv-app/PrebuiltGmsCore
rm -rf /system/etc/default-permissions/default-permissions.xml
rm -rf /system/etc/default-permissions/gapps-permission.xml
rm -rf /system/etc/permissions/com.google.android.dialer.support.xml
rm -rf /system/etc/permissions/com.google.android.maps.xml
rm -rf /system/etc/permissions/privapp-permissions-google.xml
rm -rf /system/etc/permissions/split-permissions-google.xml
rm -rf /system/etc/preferred-apps/google.xml
rm -rf /system/etc/sysconfig/google.xml
rm -rf /system/etc/sysconfig/google_build.xml
rm -rf /system/etc/sysconfig/google_exclusives_enable.xml
rm -rf /system/etc/sysconfig/google-hiddenapi-package-whitelist.xml
rm -rf /system/etc/sysconfig/google-rollback-package-whitelist.xml
rm -rf /system/etc/sysconfig/google-staged-installer-whitelist.xml
rm -rf /system/framework/com.google.android.dialer.support.jar
rm -rf /system/framework/com.google.android.maps.jar
rm -rf /system/product/overlay/PlayStoreOverlay.apk
# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*
# Handle Magisk Magic Mount
mount -o remount,rw,errors=continue /system/priv-app/PrebuiltGmsCore 2>/dev/null
umount -l /system/priv-app/PrebuiltGmsCore 2>/dev/null
rm -rf /system/priv-app/PrebuiltGmsCore 2>/dev/null
# Purge runtime permissions
rm -rf $(find /data -iname "runtime-permissions.xml" 2>/dev/null)
