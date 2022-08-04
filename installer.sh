# This file is part of The BiTGApps Project

# Allow mounting, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  # Mount partitions
  mount -o remount,rw,errors=continue / > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system > /dev/null 2>&1
  mount -o remount,rw,errors=continue /product > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
  # Set installation layout
  SYSTEM="/system"
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    echo "! Read-only file system"
    exit 1
  fi
fi

# Product is a dedicated partition
case "$(getprop "sys.bootmode")" in
  "2" )
    if grep -q " $(readlink -f /product) " /proc/mounts; then
      ln -sf /product /system
    fi
    ;;
esac

# Detect whether in boot mode
[ -z $BOOTMODE ] && ps | grep zygote | grep -qv grep && BOOTMODE="true"
[ -z $BOOTMODE ] && ps -A 2>/dev/null | grep zygote | grep -qv grep && BOOTMODE="true"
[ -z $BOOTMODE ] && BOOTMODE="false"

# Extract utility script
if [ "$BOOTMODE" = "false" ]; then
  unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP" 2>/dev/null
fi
# Allow unpack, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  $(unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP" >/dev/null 2>&1)
fi
chmod +x "$TMP/util_functions.sh"

# Extract uninstaller script
if [ "$BOOTMODE" = "false" ]; then
  for f in bitgapps.sh microg.sh; do
    unzip -o "$ZIPFILE" "$f" -d "$TMP" 2>/dev/null
  done
fi
# Allow unpack, when installation base is Magisk
if [[ "$(getprop "sys.bootmode")" = "2" ]]; then
  for f in bitgapps.sh microg.sh; do
    $(unzip -o "$ZIPFILE" "$f" -d "$TMP" >/dev/null 2>&1)
  done
fi
for f in bitgapps.sh microg.sh; do
  chmod +x "$TMP/$f"
done

ui_print() {
  if [ "$BOOTMODE" = "true" ]; then
    echo "$1"
  fi
  if [ "$BOOTMODE" = "false" ]; then
    echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
    echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
  fi
}

recovery_actions() {
  if [ "$BOOTMODE" = "false" ]; then
    OLD_LD_LIB=$LD_LIBRARY_PATH
    OLD_LD_PRE=$LD_PRELOAD
    OLD_LD_CFG=$LD_CONFIG_FILE
    unset LD_LIBRARY_PATH
    unset LD_PRELOAD
    unset LD_CONFIG_FILE
  fi
}

recovery_cleanup() {
  if [ "$BOOTMODE" = "false" ]; then
    [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
    [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
    [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
  fi
}

on_partition_check() {
  system_as_root=`getprop ro.build.system_root_image`
  slot_suffix=`getprop ro.boot.slot_suffix`
  AB_OTA_UPDATER=`getprop ro.build.ab_update`
  dynamic_partitions=`getprop ro.boot.dynamic_partitions`
}

ab_partition() {
  device_abpartition="false"
  if [ ! -z "$slot_suffix" ]; then
    device_abpartition="true"
  fi
  if [ "$AB_OTA_UPDATER" = "true" ]; then
    device_abpartition="true"
  fi
}

system_as_root() {
  SYSTEM_ROOT="false"
  if [ "$system_as_root" = "true" ]; then
    SYSTEM_ROOT="true"
  fi
}

super_partition() {
  SUPER_PARTITION="false"
  if [ "$dynamic_partitions" = "true" ]; then
    SUPER_PARTITION="true"
  fi
}

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  { echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1; \
    sed -e 's/ = /=/g' -e 's/, /,/g' -e 's/"//g' /proc/bootconfig; \
  } 2>/dev/null | sed -n "$REGEX"
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
}

mount_apex() {
  if "$BOOTMODE"; then
    return 255
  fi
  test -d "$SYSTEM/apex" || return 1
  ui_print "- Mounting /apex"
  local apex dest loop minorx num
  setup_mountpoint /apex
  test -e /dev/block/loop1 && minorx=$(ls -l /dev/block/loop1 | awk '{ print $6 }') || minorx="1"
  num="0"
  for apex in $SYSTEM/apex/*; do
    dest=/apex/$(basename $apex | sed -E -e 's;\.apex$|\.capex$;;')
    test "$dest" = /apex/com.android.runtime.release && dest=/apex/com.android.runtime
    mkdir -p $dest
    case $apex in
      *.apex|*.capex)
        # Handle CAPEX APKs
        unzip -qo $apex original_apex -d /apex
        if [ -f "/apex/original_apex" ]; then
          apex="/apex/original_apex"
        fi
        # Handle APEX APKs
        unzip -qo $apex apex_payload.img -d /apex
        mv -f /apex/apex_payload.img $dest.img
        mount -t ext4 -o ro,noatime $dest.img $dest 2>/dev/null
        if [ $? != 0 ]; then
          while [ $num -lt 64 ]; do
            loop=/dev/block/loop$num
            (mknod $loop b 7 $((num * minorx))
            losetup $loop $dest.img) 2>/dev/null
            num=$((num + 1))
            losetup $loop | grep -q $dest.img && break
          done
          mount -t ext4 -o ro,loop,noatime $loop $dest 2>/dev/null
          if [ $? != 0 ]; then
            losetup -d $loop 2>/dev/null
          fi
        fi
      ;;
      *) mount -o bind $apex $dest;;
    esac
  done
  export ANDROID_RUNTIME_ROOT="/apex/com.android.runtime"
  export ANDROID_TZDATA_ROOT="/apex/com.android.tzdata"
  export ANDROID_ART_ROOT="/apex/com.android.art"
  export ANDROID_I18N_ROOT="/apex/com.android.i18n"
  local APEXJARS=$(find /apex -name '*.jar' | sort | tr '\n' ':')
  local FWK=$SYSTEM/framework
  export BOOTCLASSPATH="${APEXJARS}\
  $FWK/framework.jar:\
  $FWK/framework-graphics.jar:\
  $FWK/ext.jar:\
  $FWK/telephony-common.jar:\
  $FWK/voip-common.jar:\
  $FWK/ims-common.jar:\
  $FWK/framework-atb-backward-compatibility.jar:\
  $FWK/android.test.base.jar"
}

umount_apex() {
  test -d /apex || return 255
  local dest loop
  for dest in $(find /apex -type d -mindepth 1 -maxdepth 1); do
    if [ -f $dest.img ]; then
      loop=$(mount | grep $dest | cut -d" " -f1)
    fi
    (umount -l $dest
    losetup -d $loop) 2>/dev/null
  done
  rm -rf /apex 2>/dev/null
  unset ANDROID_RUNTIME_ROOT
  unset ANDROID_TZDATA_ROOT
  unset ANDROID_ART_ROOT
  unset ANDROID_I18N_ROOT
  unset BOOTCLASSPATH
}

umount_all() {
  if [ "$BOOTMODE" = "false" ]; then
    umount -l /system_root > /dev/null 2>&1
    umount -l /system > /dev/null 2>&1
    umount -l /product > /dev/null 2>&1
    umount -l /system_ext > /dev/null 2>&1
  fi
}

mount_all() {
  if "$BOOTMODE"; then
    return 255
  fi
  mount -o bind /dev/urandom /dev/random
  [ "$ANDROID_ROOT" ] || ANDROID_ROOT="/system"
  setup_mountpoint $ANDROID_ROOT
  if ! is_mounted /data; then
    mount /data
    if [ -z "$(ls -A /sdcard)" ]; then
      mount -o bind /data/media/0 /sdcard
    fi
  fi
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Set recovery fstab
  [ -f "/etc/fstab" ] && cp -f '/etc/fstab' $TMP && fstab="/tmp/fstab"
  [ -f "/system/etc/fstab" ] && cp -f '/system/etc/fstab' $TMP && fstab="/tmp/fstab"
  # Check A/B slot
  [ "$slot" ] || slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot_suffix`
  [ "$slot" ] || slot=`grep_cmdline androidboot.slot`
  [ "$slot" ] && ui_print "- Current boot slot: $slot"
  if [ "$SUPER_PARTITION" = "true" ] && [ "$device_abpartition" = "true" ]; then
    unset ANDROID_ROOT && ANDROID_ROOT="/system_root" && setup_mountpoint $ANDROID_ROOT
    for block in system product system_ext; do
      for slot in "" _a _b; do
        blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
      done
    done
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
    if ! is_mounted $ANDROID_ROOT; then
      if [ "$(grep -w -o '/system_root' $fstab)" ]; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system_root' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
      fi
      if [ "$(grep -w -o '/system' $fstab)" ]; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
      fi
      mount -o ro -t auto $BLOCK $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto $BLOCK $ANDROID_ROOT > /dev/null 2>&1
    fi
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
      if ! is_mounted /product; then
        BLOCK=`grep -v '#' $fstab | grep -E '/product' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        mount -o ro -t auto $BLOCK /product > /dev/null 2>&1
        mount -o rw,remount -t auto $BLOCK /product > /dev/null 2>&1
      fi
    fi
    if [ "$(grep -w -o '/system_ext' $fstab)" ]; then
      ui_print "- Mounting /system_ext"
      mount -o ro -t auto /dev/block/mapper/product$slot /system_ext > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product$slot /system_ext > /dev/null 2>&1
      if ! is_mounted /system_ext; then
        BLOCK=`grep -v '#' $fstab | grep -E '/system_ext' | grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        mount -o ro -t auto $BLOCK /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto $BLOCK /system_ext > /dev/null 2>&1
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" = "true" ] && [ "$device_abpartition" = "false" ]; then
    unset ANDROID_ROOT && ANDROID_ROOT="/system_root" && setup_mountpoint $ANDROID_ROOT
    for block in system product system_ext; do
      blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
    done
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/product /product > /dev/null 2>&1
    fi
    if [ "$(grep -w -o '/system_ext' $fstab)" ]; then
      ui_print "- Mounting /system_ext"
      mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
    fi
  fi
  if [ "$SUPER_PARTITION" = "false" ] && [ "$device_abpartition" = "false" ]; then
    ui_print "- Mounting /system"
    mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto $ANDROID_ROOT > /dev/null 2>&1
    if ! is_mounted $ANDROID_ROOT; then
      if [ -e "/dev/block/by-name/system" ]; then
        BLOCK="/dev/block/by-name/system"
      elif [ -e "/dev/block/bootdevice/by-name/system" ]; then
        BLOCK="/dev/block/bootdevice/by-name/system"
      elif [ -e "/dev/block/platform/*/by-name/system" ]; then
        BLOCK="/dev/block/platform/*/by-name/system"
      else
        BLOCK="/dev/block/platform/*/*/by-name/system"
      fi
      # Do not proceed without system block
      [ -z "$BLOCK" ] && on_abort "! Cannot find system block"
      # Mount using block device
      mount $BLOCK $ANDROID_ROOT > /dev/null 2>&1
    fi
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /product > /dev/null 2>&1
      mount -o rw,remount -t auto /product > /dev/null 2>&1
    fi
  fi
  if [ "$SUPER_PARTITION" = "false" ] && [ "$device_abpartition" = "true" ]; then
    ui_print "- Mounting /system"
    mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
    mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
    is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT"
    if [ "$(grep -w -o '/product' $fstab)" ]; then
      ui_print "- Mounting /product"
      mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
    fi
  fi
  # Mount bind operation
  case $ANDROID_ROOT in
    /system_root) setup_mountpoint /system;;
    /system)
      if [ -f "/system/system/build.prop" ]; then
        setup_mountpoint /system_root
        mount --move /system /system_root
        mount -o bind /system_root/system /system
      fi
    ;;
  esac
  if is_mounted /system_root; then
    if [ -f "/system_root/build.prop" ]; then
      mount -o bind /system_root /system
    else
      mount -o bind /system_root/system /system
    fi
  fi
  # Set installation layout
  SYSTEM="/system"
  # System is writable
  if ! touch $SYSTEM/.rw >/dev/null 2>&1; then
    on_abort "! Read-only file system"
  fi
  # Product is a dedicated partition
  if is_mounted /product; then
    ln -sf /product /system
  fi
}

unmount_all() {
  if [ "$BOOTMODE" = "false" ]; then
    ui_print "- Unmounting partitions"
    umount_apex
    if [ "$(grep -w -o '/system_root' $fstab)" ]; then
      umount -l /system_root > /dev/null 2>&1
    fi
    if [ "$(grep -w -o '/system' $fstab)" ]; then
      umount -l /system > /dev/null 2>&1
    fi
    umount -l /system_root > /dev/null 2>&1
    umount -l /system > /dev/null 2>&1
    umount -l /product > /dev/null 2>&1
    umount -l /system_ext > /dev/null 2>&1
    umount -l /dev/random > /dev/null 2>&1
  fi
}

f_cleanup() { (find .$TMP -mindepth 1 -maxdepth 1 -type f -not -name 'recovery.log' -not -name 'busybox-arm' -exec rm -rf '{}' \;); }

d_cleanup() { (find .$TMP -mindepth 1 -maxdepth 1 -type d -exec rm -rf '{}' \;); }

on_abort() {
  ui_print "$*"
  $BOOTMODE && exit 1
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "! Installation failed"
  ui_print " "
  true
  sync
  exit 1
}

on_installed() {
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "- Installation complete"
  ui_print " "
  true
  sync
  exit "$?"
}

RTP_cleanup() {
  # Did this 6.0+ system already boot and generated runtime permissions
  if [ -e /data/system/users/0/runtime-permissions.xml ]; then
    # Purge the runtime permissions to prevent issues after uninstalling GApps
    rm -rf /data/system/users/*/runtime-permissions.xml
  fi
  # Did this 11.0+ system already boot and generated runtime permissions
  RTP="$(find /data -iname "runtime-permissions.xml" 2>/dev/null)"
  if [ -e "$RTP" ]; then
    # Purge the runtime permissions to prevent issues after uninstalling GApps
    rm -rf "$RTP"
  fi
}

get_flags() {
  DATA="false"
  DATA_DE="false"
  if grep ' /data ' /proc/mounts | grep -vq 'tmpfs'; then
    # Data is writable
    touch /data/.rw && rm /data/.rw && DATA="true"
    # Data is decrypted
    if $DATA && [ -d "/data/system" ]; then
      touch /data/system/.rw && rm /data/system/.rw && DATA_DE="true"
    fi
  fi
  if [ -z $KEEPFORCEENCRYPT ]; then
    # No data access means unable to decrypt in recovery
    if { ! $DATA && ! $DATA_DE; }; then
      KEEPFORCEENCRYPT="true"
    else
      KEEPFORCEENCRYPT="false"
    fi
  fi
  if [ "$KEEPFORCEENCRYPT" = "true" ]; then
    on_abort "! Encrypted data partition"
  fi
}

on_uninstall() {
  if [ -d "/system/priv-app/MicroGGMSCore" ]; then
    ui_print "- Uninstalling MicroG"
    source $TMP/microg.sh && return 255
  fi
  if [ -d "/system/priv-app/SetupWizardPrebuilt" ]; then
    on_abort "! SetupWizard Installed"
  fi
  if [ -d "/system/priv-app/PrebuiltGmsCore" ]; then
    ui_print "- Uninstalling GApps"
    source $TMP/bitgapps.sh
  fi
}

print_title() {
  local LEN ONE TWO BAR
  ONE=$(echo -n $1 | wc -c)
  TWO=$(echo -n $2 | wc -c)
  LEN=$TWO
  [ $ONE -gt $TWO ] && LEN=$ONE
  LEN=$((LEN + 2))
  BAR=$(printf "%${LEN}s" | tr ' ' '*')
  ui_print "$BAR"
  ui_print " $1 "
  [ "$2" ] && ui_print " $2 "
  ui_print "$BAR"
}

print_title "BiTGApps v1.0 Uninstaller"

# Load utility functions
. $TMP/util_functions.sh

# End method
