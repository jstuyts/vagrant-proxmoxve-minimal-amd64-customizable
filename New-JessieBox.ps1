<#
.SYNOPSIS
    Creates a Vagrant box for Debian 8 (Jessie).

.DESCRIPTION
    The New-JessieBox function creates a Vagrant box with a minimal installation of
    Debian 8 (Jessie). The box is customizable using the definition file, which is
    written in PowerShell object notation (PSON).

    The following things can be customized in the definition file:
    * The name of the box.
    * The amount of memory in the box.
    * The number of disks.
    * The partioning of the first disk.

    SECURITY NOTE: The contents of the definition file are not parsed, but are fed 
    directly to PowerShell. ONLY USE DEFINITION FILES YOU FULL TRUST.

.PARAMETER DefinitionFile
    The path to the definition file. The contents must be PowerShell object
    notation (PSON).

    SECURITY NOTE: The contents of this file are not parsed, but are fed directly to
    PowerShell. ONLY USE DEFINITION FILES YOU FULL TRUST.

.PARAMETER Headless
    If given the VirtualBox GUI of the virtual machine will not be shown.

.EXAMPLE
    C:\PS> New-JessieBox.ps1 mem_2GiB-disk_40GiB(system_8GiB-swap_1GiB).pson 
    Assuming the definition file describes a box with the following characteristics:
    * 2 GiB of memory
    * 1 disk of 40 GiB
    * A system partition of 8 GiB
    * A swap partition of 1 GiB

    New-JessieBox will create a VirtualBox virtual machine, install Jessie on it and
    package the virtual machine as a Vagrant box.
#>
param
  (
  [parameter( Mandatory = $true )][string]$DefinitionFile,
  [parameter( Mandatory = $false )][switch]$Headless
  )

function Assert-CommandExists
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$ApplicationName,
    [parameter( Mandatory = $true )][string[]]$Command,
    [parameter( Mandatory = $false )][string[]]$Parameters,
    [parameter( Mandatory = $true )][string[]]$HomePageUrl
    )

  try
    {
    & $Command $Parameters | Out-Null
    }
  catch
    {
    # No action needed. Ignore errors and rely on the return value for command detection.
    }
  finally
    {
    $DoesCommandExist = $?
    }
  if ( -not $DoesCommandExist )
    {
    throw "`"$Command`" (which is part of $ApplicationName) must be installed and added to `"`$env:Path`". Download from: $HomePageUrl"
    }
  }

function Get-PortCountParameterName
  {
  $VirtualBoxVersion = & VBoxManage --version
  if ( $VirtualBoxVersion -lt '4.3' )
    {
    $result = '--sataportcount'
    }
  else
    {
    $result = '--portcount'
    }

  $result;
  }

function Test-RunningVirtualMachine
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Name
    )

  ( & VBoxManage list runningvms | Select-String $Name -SimpleMatch ) -ne $null
  }

function Stop-VirtualMachineIfRunning
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Name
    )

  if ( Test-RunningVirtualMachine $Name )
    {
    & VBoxManage controlvm $Name poweroff
    }
  }

function Test-VirtualMachine
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Name
    )

  & VBoxManage showvminfo $Name | Out-Null
  $?
  }

function Unregister-VirtualMachineIfExists
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Name
    )

  if ( Test-VirtualMachine $Name )
    {
    & VBoxManage unregistervm $Name --delete
    }
  }

function Remove-ItemIfExists
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Path
    )

  if ( Test-Path $Path )
    {
    Remove-Item $Path -Recurse -Force
    }
  }

function Assert-FileHasSha512Hash
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Path,
    [parameter( Mandatory = $true )][string[]]$ExpectedSha512
    )

  $ActualSha512 = ( Get-FileHash $Path -Algorithm SHA512 ).Hash
  if ( ( $ExpectedSha512.ToLower() ) -ne ( $ActualSha512.ToLower() ) )
    {
    throw "`"$Path`" was expected to have SHA-512: $ExpectedSha512, but actually has SHA-512: $ActualSha512"
    }
  }

function Wait-InstallationFinished
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$Name
    )

  while ( Test-RunningVirtualMachine $Name )
    {
    Start-Sleep -Seconds 2
    }
  }

function Copy-ToUnixItem
  {
  param
    (
    [parameter( Mandatory = $true )][string[]]$SourcePath,
    [parameter( Mandatory = $true )][string[]]$DestinationPath
    )

  $Contents = Get-Content $SourcePath -Raw
  $ContentsWithUnixLineEndings = $Contents -replace '\r?\n', "`n"
  $ContentsWithUnixLineEndingsAsUtf8Bytes = [System.Text.Encoding]::UTF8.GetBytes( $ContentsWithUnixLineEndings )
  Set-Content $DestinationPath $ContentsWithUnixLineEndingsAsUtf8Bytes -Encoding Byte
  }

function coalesce
  {
  param
    (
    [parameter( Mandatory = $false )][string[]]$Values
    )

  $result = $null

  $ValueIndex = 0
  while ( $result -eq $null -and $ValueIndex -lt $Values.Length )
    {
    $result = $Values[ $ValueIndex ]
    $ValueIndex += 1
    }

  $result
  }

# Parameter validation

if ( -not ( Test-Path $DefinitionFile ) )
  {
  throw "`"$DefinitionFile`" does not exist."
  }

# Environment validation

Assert-CommandExists -ApplicationName Vagrant -Command vagrant -Parameters --version -HomePageUrl https://www.vagrantup.com/
Assert-CommandExists -ApplicationName VirtualBox -Command VBoxManage -Parameters '-v' -HomePageUrl https://www.virtualbox.org/
Assert-CommandExists -ApplicationName 7-Zip -Command 7z -Parameters t, 7z-presence-test.zip -HomePageUrl http://7-zip.org/
Assert-CommandExists -ApplicationName GnuWin -Command cpio -Parameters --version -HomePageUrl http://gnuwin32.sourceforge.net/
Assert-CommandExists -ApplicationName 'Open Source for Win32 by TumaGonx Zakkum' -Command mkisofs -Parameters -version -HomePageUrl http://opensourcepack.blogspot.nl/p/cdrtools.html

# Load the definition

$DefinitionAsString = ( Get-Content $DefinitionFile | Out-String )
$Definition = ( Invoke-Expression $DefinitionAsString )

# Environment-specific values

$IsoFolderPath = Join-Path ( Get-Location ) iso
$CustomIsoPath = Join-Path $IsoFolderPath custom.iso

$BuildFolderPath = Join-Path ( Get-Location ) build
$BuildVboxFolderPath = Join-Path $BuildFolderPath vbox
$BuildIsoFolderPath = Join-Path $BuildFolderPath iso
$BuildIsoCustomFolderPath = Join-Path $BuildIsoFolderPath custom

$StartvmParameters = 'startvm', $Definition.Name
if ( $Headless )
  {
  $StartvmParameters += '--type', 'headless'
  }

# The main script

Stop-VirtualMachineIfRunning $Definition.Name
Unregister-VirtualMachineIfExists $Definition.Name

Remove-ItemIfExists $BuildFolderPath
Remove-ItemIfExists $CustomIsoPath
Remove-ItemIfExists ( Join-Path ( Get-Location ) "$( $Definition.Name ).box" )

if ( -not ( Test-path $IsoFolderPath ) )
  {
  New-Item -Type Directory $IsoFolderPath | Out-Null
  }
New-Item -Type Directory $BuildVboxFolderPath | Out-Null
New-Item -Type Directory $BuildIsoCustomFolderPath | Out-Null

$IsoUrlAsUri = [Uri]$Definition.IsoUrl
$IsoUrlPathSegments = $IsoUrlAsUri.Segments
$LocalInstallationIsoPath = Join-Path $IsoFolderPath ( $IsoUrlPathSegments[ $IsoUrlPathSegments.Length - 1 ] )
if ( -not ( Test-Path $LocalInstallationIsoPath ) )
  {
  Invoke-WebRequest $IsoUrlAsUri -OutFile $LocalInstallationIsoPath
  }
Assert-FileHasSha512Hash $LocalInstallationIsoPath $Definition.IsoSha512

if ( -not ( Test-Path $CustomIsoPath ) )
  {
  & 7z x $LocalInstallationIsoPath "-o$BuildIsoCustomFolderPath"

  $PlatformspecificInstallationFolder = Get-ChildItem $BuildIsoCustomFolderPath -Filter install.* | Where-Object { $_.Extension -ne '' }
  $PlatformspecificInstallationFolderPath = Join-Path $BuildIsoCustomFolderPath $PlatformspecificInstallationFolder.Name
  $PlatformspecificInstallationFilesPattern = Join-Path $PlatformspecificInstallationFolderPath '*'
  $InstallationFolderPath = Join-Path $BuildIsoCustomFolderPath install
  Copy-Item $PlatformspecificInstallationFilesPattern $InstallationFolderPath -Recurse

  $CompressedInitrdPath = Join-Path $InstallationFolderPath initrd.gz
  & 7z x "-o$BuildFolderPath" $CompressedInitrdPath

  .\preseed-template.ps1 $Definition |
        Out-File ( Join-Path $BuildFolderPath preseed.cfg ) -Encoding ascii

  Push-Location $BuildFolderPath
  
  'preseed.cfg' | cpio --verbose --create --append --format='newc' --file=initrd
  Remove-Item $CompressedInitrdPath -Force
  & 7z a $CompressedInitrdPath initrd
  
  Pop-Location

  $IsolinuxFolderPath = Join-Path $BuildIsoCustomFolderPath isolinux
  $IsolinuxConfigurationFilePath = Join-Path $IsolinuxFolderPath isolinux.cfg
  Remove-Item $IsolinuxConfigurationFilePath
  Copy-Item isolinux.cfg $IsolinuxConfigurationFilePath

  $IsolinuxBootCatPath = Join-Path $IsolinuxFolderPath boot.cat
  Remove-Item $IsolinuxBootCatPath -Force

  $PostInstallationScript = coalesce $Definition.PostInstallationScript, 'late_command.sh'
  Copy-ToUnixItem $PostInstallationScript ( Join-Path $BuildIsoCustomFolderPath late_command.sh )

  # http://cdrtools.sourceforge.net/private/man/cdrecord/mkisofs.8.html
  & mkisofs `
        -rational-rock `
        -V 'Custom Debian Install CD' `
        -no-cache-inodes `
        -quiet `
        -J `
        -full-iso9660-filenames `
        -eltorito-boot isolinux/isolinux.bin `
        -eltorito-catalog isolinux/boot.cat `
        -no-emul-boot `
        -boot-load-size 4 `
        -boot-info-table `
        -o $CustomIsoPath `
        $BuildIsoCustomFolderPath
  }

if ( -not ( Test-VirtualMachine $Definition.Name ) )
  {
  & VBoxManage createvm `
        --name $Definition.Name `
        --ostype Debian_64 `
        --register `
        --basefolder $BuildVboxFolderPath

  $MemorySizeInMebibytes = coalesce $Definition.MemorySizeInMebibytes, 360
  & VBoxManage modifyvm $Definition.Name `
        --memory $MemorySizeInMebibytes `
        --boot1 dvd `
        --boot2 disk `
        --boot3 none `
        --boot4 none `
        --vram 12 `
        --pae off `
        --rtcuseutc on

  & VBoxManage storagectl $Definition.Name `
        --name 'IDE Controller' `
        --add ide `
        --controller PIIX4 `
        --hostiocache on

  & VBoxManage storageattach $Definition.Name `
        --storagectl 'IDE Controller' `
        --port 1 `
        --device 0 `
        --type dvddrive `
        --medium $CustomIsoPath

  & VBoxManage storagectl $Definition.Name `
        --name 'SATA Controller' `
        --add sata `
        --controller IntelAhci `
        ( Get-PortCountParameterName ) 1 `
        --hostiocache off

  $DiskOrdinal = 0
  $Definition.Disks | ForEach-Object {
    $Disk = $_

    $DiskImagePath = Join-Path ( Join-Path $BuildVboxFolderPath $Definition.Name ) "$( $Definition.Name )-$DiskOrdinal.vdi"
    $SizeInMebibytes = coalesce $Disk.SizeInMebibytes, 2048
    & VBoxManage createhd `
          --filename $DiskImagePath `
          --size $SizeInMebibytes

    & VBoxManage storageattach $Definition.Name `
          --storagectl 'SATA Controller' `
          --port $DiskOrdinal `
          --device 0 `
          --type hdd `
          --medium $DiskImagePath

    $DiskOrdinal += 1
  }

  & VBoxManage $StartvmParameters

  Wait-InstallationFinished $Definition.Name

  & VBoxManage storageattach $Definition.Name `
        --storagectl 'IDE Controller' `
        --port 1 `
        --device 0 `
        --type dvddrive `
        --medium emptydrive
  }

& vagrant package --base $Definition.Name --output "$( $Definition.Name ).box"
