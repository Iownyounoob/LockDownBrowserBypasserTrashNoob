# Define paths
$paths = @(
    "C:\Users\WDAGUtilityAccount\AppData\Local",
    "C:\Users\WDAGUtilityAccount\AppData\LocalLow",
    "C:\Users\WDAGUtilityAccount\AppData\Roaming"
)

foreach ($path in $paths) {
    # Rename folders in each path
    $folders = Get-ChildItem -Path $path -Directory

    if ($folders.Count -eq 0) {
        Write-Host "No folders found in $path."
    } else {
        foreach ($folder in $folders) {
            # Generate a random new name using a GUID
            $newName = [guid]::NewGuid().ToString()
            $newPath = Join-Path -Path $path -ChildPath $newName
            
            try {
                # Attempt to rename the folder
                Rename-Item -Path $folder.FullName -NewName $newPath -Force
                Write-Host "Renamed: $($folder.Name) to $newName"
            } catch {
                # Log the error message
                Write-Host "Failed to rename: $($folder.Name) - Access denied or in use."
            }
        }
    }

    # Delete contents of the current path
    $files = Get-ChildItem -Path $path -Recurse
    foreach ($file in $files) {
        try {
            Remove-Item -Path $file.FullName -Force -Recurse
            Write-Host "Deleted: $($file.FullName)"
        } catch {
            Write-Host "Failed to delete: $($file.FullName) - Access denied or in use."
        }
    }
}
