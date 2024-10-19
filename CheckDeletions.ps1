# Function to check if a file or directory exists 
function Check-FileOrDirectory {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        Write-Host "Exists: $Path"
    } else {
        Write-Host "Deleted: $Path"
    }
}

# Function to check if a registry key or property exists
function Check-RegistryProperty {
    param(
        [string]$Path,
        [string]$Property
    )
    try {
        $value = Get-ItemProperty -Path $Path -Name $Property -ErrorAction Stop
        Write-Host "Exists: $Property at $Path"
    } catch {
        Write-Host "Deleted: $Property at $Path"
    }
}

function Check-RegistryKey {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        Write-Host "Exists: Registry key $Path"
    } else {
        Write-Host "Deleted: Registry key $Path"
    }
}

# ==========================
# Check Files
# ==========================
$vmcomputeFilePath = "C:\Windows\System32\VmComputeAgent.exe"
Check-FileOrDirectory -Path $vmcomputeFilePath

# ==========================
# Check Registry Properties
# ==========================
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Property "BIOSVersion"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Property "BIOSDate"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemBiosVersion"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemBiosDate"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "VideoBiosVersion"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "ProcessorNameString"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "MachineType"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemModel"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "BaseBoardProduct"
Check-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "BaseBoardManufacturer"

Check-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "ProductId"
Check-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "RegisteredOwner"
Check-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "RegisteredOrganization"

Check-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Property "fDenyTSConnections"
Check-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server" -Property "Licensing"

# ==========================
# Check Registry Keys
# ==========================
Check-RegistryKey -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Virtualization"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Virtualization"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Virtual Machine"
Check-RegistryKey -Path "HKCU:\Software\Microsoft\Terminal Server Client"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
Check-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Remote Desktop"

# ==========================
# Output complete
# ==========================
Write-Host "Registry and file existence check complete."
