#param([string]$Platform = "", [string]$Config = "", [string]$RomSize = "256", [string]$RomName = "")
param([string]$Platform = "", [string]$Config = "", [string]$RomSize = "", [string]$RomName = "")

#
# This PowerShell script performs the heavy lifting in the build of RomWBW.  It handles the assembly
# of the HBIOS and then creates the final ROM image imbedding the other components such as the OS
# images, boot loader, and ROM disk image.
#
# The RomWBW build is heavily dependent on the concept of a hardware "platform" and the associated
# "configuration".  The build process selects a pair of files that are included in the HBIOS assembly
# to create the hardware-specific ROM image.  First, a platform file called cfg_<platform>.asm is
# included to establish the required assembly equates for the main hardware platform.  Second, a
# file from the Config subdirectory is included to tune the build for the specific setup of the
# desired hardware platform.  The platform file establishes all of the default equate values for
# the platform being built.  The config file is used to override the values in the platform file
# as desired.
#
# Note that there is a special platform called UNA.  UNA is John Coffman's hardware BIOS which is an
# alternative to HBIOS.  UNA is a single image that will run on all platforms and has a built-in
# setup mechanism so that multiple configuration are not needed.  When building for UNA, the pre-built
# UNA BIOS is simply imbedded, it is not built here.
#

#
# Establish the build platform.  It may have been passed in on the command line.  Validate
# $Platform and loop requesting a new value as long as it is not valid.  The valid platform
# names are just hard-coded for now.
#
$Platform = $Platform.ToUpper()
while ($true)
{
	if (($Platform -eq "SBC") -or ($Platform -eq "ZETA") -or ($Platform -eq "ZETA2") -or ($Platform -eq "RC") -or ($Platform -eq "RC180") -or ($Platform -eq "N8") -or ($Platform -eq "MK4") -or ($Platform -eq "UNA") -or ($Platform -eq "MT")) {break}
	$Platform = (Read-Host -prompt "Platform [SBC|ZETA|ZETA2|RC|RC180|N8|MK4|UNA|MT]").Trim().ToUpper()
}

#
# Establish the platform configuration to build.  It may have been passed in on the commandline.  Validate
# $Config and loop requesting a new value as long as it is not valid.  The file system is scanned to determine
# if the requested ConfigFile exists.  Config files must be named <platform>_<config>.asm where <platform> is
# the platform name established above and <config> is the value of $Config determined here.
#
while ($true)
{
	$PlatformConfigFile = "Config/plt_${Platform}.asm"
	$ConfigFile = "Config/${Platform}_${Config}.asm"
	if (Test-Path $ConfigFile) {break}
	if ($Config -ne "") {Write-Host "${ConfigFile} does not exist!"}

	"Configurations available:"
	Get-Item "Config/${Platform}_*.asm" | foreach {Write-Host " >", $_.Name.Substring($Platform.Length + 1, $_.Name.Length - $Platform.Length - 5)}
	$Config = (Read-Host -prompt "Configuration").Trim()
}

#
# Establish the ROM size (in KB).  It may have been passed in on the command line.  Validate
# $RomSize and loop requesting a new value as long as it is not valid.  The valid ROM sizes
# are just hard-coded for now.  The ROM size does nothing more than determine the size of the
# ROM disk portion of the ROM image.
#
while ($true)
{
	if (($RomSize -eq "256") -or ($RomSize -eq "320") -or ($RomSize -eq "512") -or ($RomSize -eq "1024")) {break}
	$RomSize = (Read-Host -prompt "ROM Size [256|320|512|1024]").Trim()
}

#
# TASM should be invoked with the proper CPU type.  Below, the CPU type is inferred
# from the platform.
#
if (($Platform -eq "N8") -or ($Platform -eq "MK4") -or ($Platform -eq "RC180")) {$CPUType = "180"} else {$CPUType = "80"}

#
# The $RomName variable determines the name of the image created by the script.  By default,
# this will be <platform>_<config>.rom.  Unless the script was invoked with a specified
# ROM filename, the name is established below.
#
if ($RomName -eq "") {$RomName = "${Platform}_${Config}"}
while ($RomName -eq "")
{
	$CP = (Read-Host -prompt "ROM Name [${Config}]").Trim()
	if ($RomName -eq "") {$RomName = $Config}
}

# If a PowerShell exception occurs, just stop the script immediately.
$ErrorAction = 'Stop'

# Directories of required build tools (TASM & cpmtools)
$TasmPath = '..\..\tools\tasm32'
$CpmToolsPath = '..\..\tools\cpmtools'

# Add tool directories to PATH and setup TASM's TABS directory path
$env:TASMTABS = $TasmPath
$env:PATH = $TasmPath + ';' + $CpmToolsPath + ';' + $env:PATH

# Initialize working variables
$OutDir = "../../Binary"		# Output directory for final image file
$RomFmt = "wbw_rom${RomSize}"		# Location of files to imbed in ROM disk
$BlankROM = "Blank${RomSize}KB.dat"	# An initial "empty" image for the ROM disk of proper size
$RomDiskFile = "RomDisk.tmp"		# Temporary filename used to create ROM disk image
$RomFile = "${OutDir}/${RomName}.rom"	# Final name of ROM image
$ComFile = "${OutDir}/${RomName}.com"	# Final name of COM image (command line loadable HBIOS/CBIOS)
$ImgFile = "${OutDir}/${RomName}.img"	# Final name of IMG image (memory loadable HBIOS/CBIOS image)

# Select the proper CBIOS to include in the ROM.  UNA is special.
if ($Platform -eq "UNA") {$CBiosFile = '../CBIOS/cbios_una.bin'} else {$CBiosFile = '../CBIOS/cbios_wbw.bin'}

# List of RomWBW proprietary apps to imbed in ROM disk.
$RomApps = "assign","fdu","format","mode","osldr","rtc","survey","syscopy","sysgen","talk","timer","xm","inttest"
#$RomApps = "mode"

""
"Building ${RomName}: ${ROMSize}KB ROM configuration ${Config} for Z${CPUType}..."
""

# Current date/time is queried here to be subsequently imbedded in image
$TimeStamp = '"' + (Get-Date -Format 'yyyy-MM-dd') + '"'

# Function to run TASM and throw an exception if an error occurs.
Function Asm($Component, $Opt, $Architecture=$CPUType, $Output="${Component}.bin", $List="${Component}.lst")
{
  $Cmd = "tasm -t${Architecture} -g3 ${Opt} ${Component}.asm ${Output} ${List}"
  $Cmd | write-host
  Invoke-Expression $Cmd | write-host
  if ($LASTEXITCODE -gt 0) {throw "TASM returned exit code $LASTEXITCODE"}
}

# Function to concatenate two binary files.
Function Concat($InputFileList, $OutputFile)
{
	Set-Content $OutputFile -Value $null
	foreach ($InputFile in $InputFileList)
	{
		Add-Content $OutputFile -Value ([System.IO.File]::ReadAllBytes($InputFile)) -Encoding byte
	}
}

#
# Since TASM has no mechanism to include files dynamically based on variables, a file
# if built on-the-fly here for imbedding in the build process.  This file is basically
# just used to include the platform and config files.  It also passes in some values
# from the build to include in the build.

@"
; RomWBW Configured for ${Platform} ${Config}, $(Get-Date -Format "s")
;
#DEFINE		TIMESTAMP	${TimeStamp}
;
PLATFORM	.EQU		PLT_${Platform}		; HARDWARE PLATFORM
ROMSIZE		.EQU		${ROMSize}		; SIZE OF ROM IN KB
;
;#INCLUDE "${PlatformConfigFile}"
#INCLUDE "${ConfigFile}"
;
"@ | Out-File "build.inc" -Encoding ASCII

# Create a local copy of the CP/M CCP and BDOS images for later use.
Copy-Item '..\cpm22\os2ccp.bin' 'ccp.bin'
Copy-Item '..\cpm22\os3bdos.bin' 'bdos.bin'

# Create a local copy of the ZSystem CCP and BDOS images for later use.
Copy-Item '..\zcpr-dj\zcpr.bin' 'zcpr.bin'
Copy-Item '..\zsdos\zsdos.bin' 'zsdos.bin'

# Assemble individual components.  Note in the case of UNA, there is less to build.
Asm 'dbgmon'
Asm 'prefix'
Asm 'romldr'
if ($Platform -ne "UNA")
{
	Asm 'hbios' '-dROMBOOT' -Output 'hbios_rom.bin' -List 'hbios_rom.lst'
	Asm 'hbios' '-dAPPBOOT' -Output 'hbios_app.bin' -List 'hbios_app.lst'
	Asm 'hbios' '-dIMGBOOT' -Output 'hbios_img.bin' -List 'hbios_img.lst'
}

#
# Once all of the individual binary components have been created above, the final
# ROM image is created by simply concatenating the pieces together as needed.
#
"Building ${RomName} output files..."

# Combine the CCP and BDOS portions of CP/M and ZSystem to create OS images
Concat 'ccp.bin','bdos.bin',$CBiosFile 'cpm.bin'
Concat 'zcpr.bin','zsdos.bin',$CBiosFile 'zsys.bin'

# Prepend a bit of boot code required to bootstrap the OS images
Concat 'prefix.bin','cpm.bin' 'cpm.sys'
Concat 'prefix.bin','zsys.bin' 'zsys.sys'

# Build 32K OS chunk containing the loader, debug monitor, and OS images
Concat 'romldr.bin', 'dbgmon.bin','cpm.bin','zsys.bin' osimg.bin

#
# Now the ROM disk image is created.  This is done by starting with a
# blank ROM disk image of the correct size, then cpmtools is used to
# add the desired files.
#

"Building ${RomSize}KB ${RomName} ROM disk data file..."

# Use the blank ROM disk image to create a working ROM disk image
Copy-Item $BlankROM $RomDiskFile

# Copy all files from the appropriate directory to the working ROM disk image
cpmcp -f $RomFmt $RomDiskFile ../RomDsk/ROM_${RomSize}KB/*.* 0:

# Add any platform specific files to the working ROM disk image
if (Test-Path "../RomDsk/${Platform}/*.*")
{
	cpmcp -f $RomFmt $RomDiskFile ../RomDsk/${Platform}/*.* 0:
}

# Add the proprietary RomWBW applications to the working ROM disk image
foreach ($App in $RomApps)
{
	cpmcp -f $RomFmt $RomDiskFile ../../Binary/Apps/$App.com 0:
}

# Add the CP/M and ZSystem system images to the ROM disk (used by SYSCOPY)
cpmcp -f $RomFmt $RomDiskFile *.sys 0:

#
# Finally, the individual binary components are concatenated together to produce
# the final images.
#
if ($Platform -eq "UNA")
{
	Copy-Item 'osimg.bin' ${OutDir}\UNA_WBW_SYS.bin
	Copy-Item $RomDiskFile ${OutDir}\UNA_WBW_ROM${ROMSize}.bin

	Concat '..\UBIOS\UNA-BIOS.BIN','osimg.bin','..\UBIOS\FSFAT.BIN',$RomDiskFile $RomFile
}
else 
{
    if ($Platform -eq "MT")
    {
        Concat 'hbios_rom.bin','osimg.bin',$RomDiskFile $RomFile

        cd Bootstrap

        $Cmd = ".\Build.cmd ${Platform} ${Config} ${Romsize} ${Romname}"
        $Cmd | write-host
        Invoke-Expression $Cmd | write-host
        if ($LASTEXITCODE -gt 0) {throw "Build bootstrap returned exit code $LASTEXITCODE"}

        cd ..

        $BootstrapFile = "${OutDir}/${RomName}_bootstrap.bin"	# Final name of bootstrap image

        Concat 'Bootstrap\bootstrap.bin',$RomFile $BootstrapFile
        
    }
    else
    {
	    Concat 'hbios_rom.bin','osimg.bin','osimg.bin','osimg.bin',$RomDiskFile $RomFile
    }

	Concat 'hbios_app.bin','osimg.bin' $ComFile
	Concat 'hbios_img.bin','osimg.bin' $ImgFile
}

# Remove the temprary working ROM disk file
Remove-Item $RomDiskFile