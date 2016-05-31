@{
    Name = 'example-proxmoxve-tiny-amd64';
    # Optional. Default: 360
    MemorySizeInMebibytes = 2048;

    # Optional. Default: $false
    #
    # It is best to use the "vagrant-vbguest" plug-in as this will install a
    # version of the guest additions that matches the version of VirtualBox:
    #     https://github.com/dotless-de/vagrant-vbguest
    #
    # If you do install the guest additions from the Debian repositories, then
    # it is best to prevent the "vagrant-vbguest" plug-in from trying to
    # upgrade the guest additions. Add the following to your "Vagrantfile":
    #     config.vbguest.no_install = true
    InstallGuestAdditions = $false;

    Disks = @(
        @{
            # Optional. Default: 16384
            SizeInMebibytes = 16384;
            # Optional. Default: <none>
            BiosBootPartitionName = 'grub';
            Partitions = @(
                @{
                    SizeInMebibytes = 4096;
                    Type = 'filesystem';
                    # Optional. Default: 'ext4'
                    FilesystemCode = 'ext4';
                    # Optional. Default: <none>
                    MountPoint = '/';
                    # Optional. Default: $false
                    IsBootable = $true;
                    # Optional. Default: <none>
                    PartitionName = 'host';
                    # Optional. Default: <none>
                    Label = 'host';
                },
                @{
                    SizeInMebibytes = 2048;
                    Type = 'swap';
                    # Optional. Default: <none>
                    PartitionName = 'swap';
                },
                @{
                    SizeInMebibytes = 10237;
                    Type = 'empty';
                    # Optional. Default: <none>
                    PartitionName = 'firstpool';
                }
            );
        },
        @{
            # Optional. Default: 16384
            SizeInMebibytes = 16384;
        }
    );

    IsoUrl = 'http://cdimage.debian.org/debian-cd/8.4.0/amd64/iso-cd/debian-8.4.0-amd64-netinst.iso';
    IsoSha512 = 'e51200021d0356f6dc84e2307218c56230c7f539634be6ffb243971e93b9d37fc63c7cec9ba58fcf0f970a89733f86d8c71e4b18e5045351536cc36aef4f261b';

    # Optional. Default: US
    CountryCode = 'US';
    # Optional. Default: en
    LanguageCode = 'en';
    # Optional. Default: UTF-8
    CharacterEncodingCode = 'UTF-8';

    # Optional. Default: us
    KeymapCode = 'us';

    # Optional. Default: GMT+0
    TimeZoneCode = 'GMT+0';

    # Optional. Default: true
    MustClockBeSynchronizedUsingNtp = 'true';

    # Optional. Default: true
    MustNonFreePackagesBeAvailable = 'true';

    # Optional. Default: <empty string>
    NamesOfAdditionalPackagesToInstall = 'less vim';

    # Optional. Default: false
    MustJoinPopularityContest = 'false';

    # Optional. Default: 'late_command.sh'
    PostInstallationScript = 'late_command.sh';
}
