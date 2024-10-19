# Define command line parameters
param (
    [switch]$all = $false,
    [switch]$reg = $false,
    [switch]$procs = $false,
    [switch]$files = $false
)

if ($all) {
    $reg = $true
    $procs = $true
    $files = $true
}

# Menu / Helper stuff
Write-Output ""
Write-Output "Example Usage: remover.ps1 -all"
Write-Output "Warning: Only run in a virtual machine!"
Write-Output "*****************************************"
Write-Output ""

# -------------------------------------------------------------------------------------------------------
# Define random string generator function

function Get-RandomString {
    $charSet = "abcdefghijklmnopqrstuvwxyz0123456789".ToCharArray()
    $randomString = ""

    for ($i = 0; $i -lt 10; $i++) {
        $randomString += $charSet | Get-Random
    }

    return $randomString
}

# -------------------------------------------------------------------------------------------------------
if ($reg) {

   # Remove or rename registry keys

    if (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Name "SystemBiosVersion" -ErrorAction SilentlyContinue) {
        Write-Output "[*] Renaming Reg Key HKLM:\HARDWARE\DESCRIPTION\System\SystemBiosVersion..."
        Set-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Name "SystemBiosVersion" -Value  $(Get-RandomString)
    } Else {
        Write-Output '[!] Reg Key HKLM:\HARDWARE\DESCRIPTION\System\SystemBiosVersion does not seem to exist! Skipping this one...'
    }

    if (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Name "SystemManufacturer" -ErrorAction SilentlyContinue) {
        Write-Output "[*] Renaming Reg Key HKLM:\HARDWARE\DESCRIPTION\System\BIOS\SystemManufacturer..."
        Set-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Name "SystemManufacturer" -Value  $(Get-RandomString)
    } Else {
        Write-Output '[!] Reg Key HKLM:\HARDWARE\DESCRIPTION\System\BIOS\SystemManufacturer does not seem to exist! Skipping this one...'
    }
	
	if (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Name "SystemProductName" -ErrorAction SilentlyContinue) {
        Write-Output "[*] Renaming Reg Key HKLM:\HARDWARE\DESCRIPTION\System\BIOS\SystemProductName..."
        Set-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Name "SystemProductName" -Value  $(Get-RandomString)
    } Else {
        Write-Output '[!] Reg Key HKLM:\HARDWARE\DESCRIPTION\System\BIOS\SystemProductName does not seem to exist! Skipping this one...'
    }
	
	# Continue with other keys you may want to modify or remove...
	
	if (Get-ItemProperty -Path "HKLM:\HARDWARE\DEVICEMAP\Scsi\Scsi Port 0\Scsi Bus 0\Target Id 0\Logical Unit Id 0" -Name "Identifier" -ErrorAction SilentlyContinue) {
        Write-Output "[*] Renaming Reg Key HKLM:\HARDWARE\DEVICEMAP\Scsi\Scsi Port 0\Scsi Bus 0\Target Id 0\Logical Unit Id 0\Identifier..."
        Set-ItemProperty -Path "HKLM:\HARDWARE\DEVICEMAP\Scsi\Scsi Port 0\Scsi Bus 0\Target Id 0\Logical Unit Id 0" -Name "Identifier" -Value  $(Get-RandomString)
    } Else {
        Write-Output '[!] Reg Key HKLM:\HARDWARE\DEVICEMAP\Scsi\Scsi Port 0\Scsi Bus 0\Target Id 0\Logical Unit Id 0\Identifier does not seem to exist! Skipping this one...'
    }

    # Repeat similar checks for any other keys you need to handle...

    # If you have other registry keys to handle, you can add them here.
}

# -------------------------------------------------------------------------------------------------------

Write-Output "** Done!" 
