param([string]$Platform = "", [string]$Config = "", [string]$RomSize = "", [string]$RomName = "")

#
# Establish the ROM size (in KB).  It may have been passed in on the command line.  Validate
# $RomSize and loop requesting a new value as long as it is not valid.  The valid ROM size
# determines the size of the image that is going to be loaded by the bootloader and must be 
# a multiple of 32K..
#
while ($true)
{
    if($Romsize -eq "")
    {
        $remainder = 1;
    }
    else
    {
        $remainder = $Romsize % 32
    }
    
	if ($remainder -eq 0) {break}
	$RomSize = (Read-Host -prompt "ROM Size [must be multiple of 32K]").Trim()
}

#
# Since TASM has no mechanism to include files dynamically based on variables, a file
# if built on-the-fly here for imbedding in the build process.  This file is basically
# just used to include the platform and config files.  It also passes in some values
# from the build to include in the build.

@"
ROMSIZE		.EQU		${ROMSize}		; SIZE OF ROM IN KB
"@ | Out-File "build.inc" -Encoding ASCII

$CPUType = "80"
$RomName = "bootstrap"

# If a PowerShell exception occurs, just stop the script immediately.
$ErrorAction = 'Stop'

# Directories of required build tools (TASM & cpmtools)
$TasmPath = '..\..\..\tools\tasm32'
$CpmToolsPath = '..\..\..\tools\cpmtools'

# Add tool directories to PATH and setup TASM's TABS directory path
$env:TASMTABS = $TasmPath
$env:PATH = $TasmPath + ';' + $CpmToolsPath + ';' + $env:PATH

# Initialize working variables
$OutDir = "."		# Output directory for final image file

$RomFile = "${OutDir}/${RomName}.rom"	# Final name of ROM image



""
"Building ${RomName} for Z${CPUType}..."
""

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


# Assemble bootloader.
Asm 'bootloader'

# Bootstrap.inc is created from bootloader so that bootstrap can write the bootloader to memory
$bootloader = [System.IO.File]::ReadAllBytes('bootloader.bin')

$bootstrapinc = ""
foreach($byte in $bootloader)
{
    $bootstrapinc = $bootstrapinc + "    INI
    .DB  $byte
"
}


@"
${bootstrapinc}
"@ | Out-File "bootstrap.inc" -Encoding ASCII

# Assemble bootstrap.
Asm 'bootstrap'
