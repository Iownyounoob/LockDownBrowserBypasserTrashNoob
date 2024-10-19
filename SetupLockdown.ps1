# Define paths  
$projectRoot = "C:\Users\WDAGUtilityAccount\Desktop\LockdownBrowserProject"
$lockdownBrowserPath = "C:\Program Files (x86)\Respondus\LockDown Browser\LockDownBrowser.exe"
$dllFilePath = "$projectRoot\Notepad.dll"  # DLL to inject
$injectionToolPath = "$projectRoot\withdll.exe"  # Injection tool path

# Check if the required files exist
if (-Not (Test-Path $dllFilePath)) {
    Write-Host "DLL file not found: $dllFilePath"
    Exit 1
}

if (-Not (Test-Path $injectionToolPath)) {
    Write-Host "Injection tool not found: $injectionToolPath"
    Exit 1
}

if (-Not (Test-Path $lockdownBrowserPath)) {
    Write-Host "LockDown Browser not found at: $lockdownBrowserPath"
    Exit 1
}

# ==========================
# Set up the rldb:// protocol in the registry for LockDown Browser with DLL injection
# ==========================
New-PSDrive -PSProvider Registry -Root HKEY_CLASSES_ROOT -Name HKCR -ErrorAction SilentlyContinue
Set-ItemProperty -Path "HKCR:\rldb\shell\open\command" -Name "(Default)" -Value ('"' + $injectionToolPath + '" "/d:' + $dllFilePath + '" "' + $lockdownBrowserPath + '" "%1"')

# ==========================
# Deletion and Cleanup Section
# ==========================

# Function to take ownership and delete a file or directory
function Delete-FileOrDirectory {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        Write-Host "Attempting to delete: $Path"
        takeown /f $Path /a
        icacls $Path /grant "Everyone:(D)" /T /C
        Remove-Item $Path -Recurse -Force -ErrorAction Ignore
        if (-Not (Test-Path $Path)) {
            Write-Host "Deleted: $Path"
        } else {
            Write-Host "Failed to delete: $Path"
        }
    } else {
        Write-Host "Already deleted: $Path"
    }
}

# Function to take ownership and delete a registry key
function Delete-RegistryKey {
    param(
        [string]$Path
    )
    if (Test-Path $Path) {
        Write-Host "Attempting to delete registry key: $Path"
        Set-ItemProperty -Path $Path -Name "owner" -Value "Everyone" -ErrorAction Ignore
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Ignore
        if (-Not (Test-Path $Path)) {
            Write-Host "Deleted registry key: $Path"
        } else {
            Write-Host "Failed to delete registry key: $Path"
        }
    } else {
        Write-Host "Registry key already deleted: $Path"
    }
}

# Function to take ownership and delete a registry property
function Delete-RegistryProperty {
    param(
        [string]$Path,
        [string]$Property
    )
    try {
        $value = Get-ItemProperty -Path $Path -Name $Property -ErrorAction Stop
        Write-Host "Attempting to delete registry property: $Property at $Path"
        Remove-ItemProperty -Path $Path -Name $Property -ErrorAction Ignore
        Write-Host "Deleted registry property: $Property at $Path"
    } catch {
        Write-Host "Registry property already deleted: $Property at $Path"
    }
}

# ==========================
# Delete RDP and VM-Related Files and Registry Keys
# ==========================

# 1. Remove RDP Client settings
Delete-RegistryKey -Path "HKCU:\Software\Microsoft\Terminal Server Client"

# 2. Remove RDP settings under Policies
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"

# 3. Remove additional Terminal Services settings
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Remote Desktop"

# 4. Remove VmComputeAgent.exe
$vmcompute_path = "C:\Windows\System32\VmComputeAgent.exe"
Delete-FileOrDirectory -Path $vmcompute_path

# ==========================
# Check Remaining Files and Registry Properties
# ==========================
$hypervDriverPath = "C:\Windows\System32\drivers\vmhcsrv.sys"
Delete-FileOrDirectory -Path $hypervDriverPath

$vmguestPath = "C:\Windows\System32\vmguest.iso"
Delete-FileOrDirectory -Path $vmguestPath

# ==========================
# Delete Registry Properties (Common VM indicators)
# ==========================
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Property "BIOSVersion"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS" -Property "BIOSDate"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemBiosVersion"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemBiosDate"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "VideoBiosVersion"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "ProcessorNameString"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "MachineType"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "SystemModel"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "BaseBoardProduct"
Delete-RegistryProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System" -Property "BaseBoardManufacturer"

# ==========================
# Delete Windows NT System Properties
# ==========================
Delete-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "ProductId"
Delete-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "RegisteredOwner"
Delete-RegistryProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Property "RegisteredOrganization"

# ==========================
# Delete Registry Keys (Common VM indicators)
# ==========================
Delete-RegistryKey -Path "HKLM:\HARDWARE\DESCRIPTION\System\BIOS"
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Virtualization"
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Virtualization"
Delete-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Virtual Machine"

# Additional Virtualization-Related Registry Keys
Delete-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\vmicvss"
Delete-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\vmicguestinterface"
Delete-RegistryKey -Path "HKLM:\SYSTEM\CurrentControlSet\Services\vmicrdv"

# ==========================
# Final Output
# ==========================
Write-Host "Setup complete. Registry and file existence checks are complete."
