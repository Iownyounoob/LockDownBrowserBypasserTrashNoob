# Define the directories to monitor and clean
$tempFolderPath = "C:\Users\WDAGUtilityAccount\AppData\Local\Temp"
$respondusFolderPath = "C:\Users\WDAGUtilityAccount\AppData\Local\Respondus"

# Function to delete everything inside a folder (including subdirectories)
function Clear-Folder($path) {
    try {
        if (Test-Path $path) {
            Get-ChildItem -Path $path -Recurse | ForEach-Object {
                try {
                    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host "Deleted: $($_.FullName)"
                } catch {
                    Write-Host "Failed to delete: $($_.FullName) - Error: $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Host "Failed to clear items in: $path - Error: $($_.Exception.Message)"
    }
}

# Clean up existing files and subfolders in the Temp folder
Clear-Folder $tempFolderPath

# Clean up existing files and subfolders in the Respondus folder
Clear-Folder $respondusFolderPath

# Create a FileSystemWatcher to monitor the Respondus directory
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $respondusFolderPath
$watcher.Filter = "*.*"   # Monitor all files
$watcher.IncludeSubdirectories = $true  # Monitor all subdirectories as well

# Specify what events to monitor
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite'

# Define the action to take when a file or directory is created or changed
$action = {
    param($source, $eventArgs)
    $itemPath = $eventArgs.FullPath

    try {
        # If the item exists, rename it randomly and delete it
        if (Test-Path $itemPath) {
            $newName = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($itemPath),
                [System.IO.Path]::GetFileNameWithoutExtension($itemPath) + "_" + [guid]::NewGuid().ToString() + [System.IO.Path]::GetExtension($itemPath)
            )
            Rename-Item -Path $itemPath -NewName $newName -ErrorAction Stop
            Write-Host "Renamed: $itemPath to $newName"
            Remove-Item -Path $newName -Force -ErrorAction Stop
            Write-Host "Deleted: $newName"
        }
    } catch {
        Write-Host "Failed to process: $itemPath - Error: $($_.Exception.Message)"
    }
}

# Register events for created and changed items
Register-ObjectEvent $watcher 'Created' -Action $action
Register-ObjectEvent $watcher 'Changed' -Action $action

# Start the watcher
$watcher.EnableRaisingEvents = $true

# Keep the script running
Write-Host "Monitoring $respondusFolderPath for file changes... Press [Ctrl + C] to exit."
while ($true) {
    Start-Sleep -Seconds 1
}
