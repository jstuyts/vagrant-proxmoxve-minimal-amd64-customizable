param
  (
  [parameter( Mandatory = $true )][hashtable]$Data
  )

$LanguageCode = coalesce $Data.LanguageCode, 'en'
$CountryCode = coalesce $Data.CountryCode, 'US'
$CharacterEncodingCode = coalesce $Data.CharacterEncodingCode, 'UTF-8'

$KeymapCode = coalesce $Data.KeymapCode, 'us'

$TimeZoneCode = coalesce $Data.TimeZoneCode, 'GMT+0'
$MustClockBeSynchronizedUsingNtp = coalesce $Data.MustClockBeSynchronizedUsingNtp, 'true'

$MustNonFreePackagesBeAvailable = coalesce $Data.MustNonFreePackagesBeAvailable, 'true'
$MustContribPackagesBeAvailable = coalesce $Data.MustContribPackagesBeAvailable, 'true'

$NamesOfAdditionalPackagesToInstall = coalesce $Data.NamesOfAdditionalPackagesToInstall, ''

$MustJoinPopularityContest = coalesce $Data.MustJoinPopularityContest, 'false'

"### Localization
d-i debian-installer/locale string ${LanguageCode}_$CountryCode
d-i debian-installer/language string $LanguageCode
d-i debian-installer/country string $CountryCode
d-i debian-installer/locale string ${LanguageCode}_$CountryCode.$CharacterEncodingCode
d-i localechooser/supported-locales multiselect ${LanguageCode}_$CountryCode.$CharacterEncodingCode

# Keyboard selection.
d-i keyboard-configuration/xkb-keymap select $KeymapCode

### Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string vagrant-jessie-minimal-amd64-customizable
d-i netcfg/hostname string vagrant-jessie-minimal-amd64-customizable
d-i netcfg/get_domain string vagrantup.com
d-i netcfg/wireless_wep string

d-i hw-detect/load_firmware boolean true

### Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string cdn.debian.net
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string
d-i mirror/suite string jessie

### Account setup
d-i passwd/root-login boolean false
d-i passwd/user-fullname string
d-i passwd/username string vagrant
d-i passwd/user-password password vagrant
d-i passwd/user-password-again password vagrant

### Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string $TimeZoneCode
d-i clock-setup/ntp boolean $MustClockBeSynchronizedUsingNtp

### Partitioning
d-i partman-auto/method string regular
d-i partman-auto/alignment string optimal
d-i partman-auto/disk string /dev/sda
d-i partman-auto/expert_recipe string \
      custom-recipe :: \"

$PrimaryDisk = $Data.Disks[0]

$DiskSizeInMebibytes = coalesce $PrimaryDisk.SizeInMebibytes, 4096

# Remove space for the boot sector and other metadata
$MetadataAtFrontOfDiskSizeInMebibytes = 1
$AvailableSpaceInMebibytes = $DiskSizeInMebibytes - 2
$SpaceAllocatedByPartitionsInMebibytes = 0
$PrimaryDisk.Partitions | ForEach-Object {
  $Partition = $_

  $IsFirstPartition = $SpaceAllocatedByPartitionsInMebibytes -eq 0
  if ( $IsFirstPartition )
    {
    $MetadataAtFrontOfDiskSizeToAddToPreviousAllocatedSpaceInMebibytes = 0
    }
  else
    {
    $MetadataAtFrontOfDiskSizeToAddToPreviousAllocatedSpaceInMebibytes = $MetadataAtFrontOfDiskSizeInMebibytes
"              . \"
    }

  $PreviousSpaceAllocatedByPartitionsInMebibytes = $SpaceAllocatedByPartitionsInMebibytes
  $SpaceAllocatedByPartitionsInMebibytes += $Partition.SizeInMebibytes

  $PreviousSpaceAllocatedByPartitionsInMegabytes = ( $PreviousSpaceAllocatedByPartitionsInMebibytes + $MetadataAtFrontOfDiskSizeToAddToPreviousAllocatedSpaceInMebibytes ) * 1048576 / 1000000.0
  $SpaceAllocatedByPartitionsInMegabytes = ( $SpaceAllocatedByPartitionsInMebibytes + $MetadataAtFrontOfDiskSizeInMebibytes ) * 1048576 / 1000000.0
  $PartitionSizeForPartman = [long]( $SpaceAllocatedByPartitionsInMegabytes - $PreviousSpaceAllocatedByPartitionsInMegabytes )

  switch ( $Partition.Type )
    {
    'filesystem'
      {
      $FilesystemCode = coalesce $Partition.FilesystemCode, ext4
"              $PartitionSizeForPartman $PartitionSizeForPartman $PartitionSizeForPartman $FilesystemCode \
                      `$primary{ } \"
      if ( $Partition.IsBootable )
        {
"                      `$bootable{ } \"
        }
"                      method{ format } format{ } \
                      use_filesystem{ } filesystem{ $FilesystemCode } \"
      if ( $Partition.MountPoint -ne $null )
        {
"                      mountpoint{ $( $Partition.MountPoint ) } \"
        }
      }
    'swap'
      {
"              $PartitionSizeForPartman $PartitionSizeForPartman $PartitionSizeForPartman linux-swap \
                      `$primary{ } \
                      method{ swap } format{ } \"
      }
    default
      {
      throw "Unknown partition type: $( $Partition.Type )."
      }
    }
  if ( $Partition.Label -ne $null )
    {
"                      label{ $( $Partition.Label ) } \"
    }
}
if ( $SpaceAllocatedByPartitionsInMebibytes -gt $AvailableSpaceInMebibytes )
  {
  throw "Allocated space: $SpaceAllocatedByPartitionsInMebibytes MiB, exceeds available space: $AvailableSpaceInMebibytes MiB."
  }

$IsPaddingPartitionNeededAtEnd = $SpaceAllocatedByPartitionsInMebibytes -lt $AvailableSpaceInMebibytes
if ( $IsPaddingPartitionNeededAtEnd )
  {
  $SpaceLeftFreeInMebibytes = $AvailableSpaceInMebibytes - $SpaceAllocatedByPartitionsInMebibytes
  if ( $SpaceLeftFreeInMebibytes -lt 64 )
    {
    throw "When not completely using the disk at least 64 MiB must be left free for the padding partition. But only $SpaceLeftFreeInMebibytes MiB was left free."
    }
"             . \
              67 67 67 ext4 \
                      `$primary{ } \
                      method{ keep } \
                      use_filesystem{ } filesystem{ ext4 } \"
  }
"              .
d-i partman-basicfilesystems/no_mount_point boolean false
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman/mount_style select uuid

### Apt setup
d-i apt-setup/non-free boolean $MustNonFreePackagesBeAvailable
d-i apt-setup/contrib boolean $MustContribPackagesBeAvailable
d-i apt-setup/services-select multiselect security, volatile
d-i apt-setup/security_host string security.debian.org
d-i apt-setup/volatile_host string volatile.debian.org

### Package selection
tasksel tasksel/first multiselect

d-i pkgsel/include string openssh-server build-essential nfs-common ssh ca-certificates linux-headers-amd64 virtualbox-guest-dkms virtualbox-guest-utils $NamesOfAdditionalPackagesToInstall
d-i pkgsel/upgrade select safe-upgrade

popularity-contest popularity-contest/participate boolean $MustJoinPopularityContest

### GRUB
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev  string /dev/sda

### Finishing up the installation
d-i finish-install/keep-consoles boolean true
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/poweroff boolean true

#### Advanced options
d-i preseed/late_command string cp /cdrom/late_command.sh /target/tmp/late_command.sh && in-target chmod +x /tmp/late_command.sh && in-target /tmp/late_command.sh"
