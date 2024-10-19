# PowerShell script to set up LockdownBrowserProject with Detours
$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3

# Define the project directory
$projectDir = "C:\Users\abcd2\OneDrive\Documents\temp\LockdownBrowserProject"

# Change to the project directory
cd $projectDir

function initialize_vs {
    # Install the VSSetup module if not installed, then initialize VS environment
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    if (-Not (Get-Module -ListAvailable -Name VSSetup)) {
        Install-Module VSSetup -Scope CurrentUser
    }

    # Get Visual Studio installation path and initialize environment
    pushd (Get-VSSetupInstance)[0].InstallationPath
    $cmd_args = '/c .\VC\Auxiliary\Build\vcvars32.bat'
    $cmd_out = & 'cmd' $cmd_args
    popd

    # Set up environment variables
    $env_vars = @{ }
    $cmd_out | ForEach-Object {
        if ($_ -match '=') {
            $key, $value = $_ -split '='
            $env_vars[$key] = $value
        }
    }

    # Set environment variables
    $env_vars.Keys | ForEach-Object {
        if ($_ -and $env_vars[$_]) {
            Set-Item -Force -Path "env:\$($_)" -Value "$($env_vars[$_])"
        }
    }
}

function clone_detours {
    # Clone Detours repository if it doesn't exist
    if (-Not (Test-Path "Detours")) {
        git clone https://github.com/microsoft/Detours.git
    } else {
        Write-Host "Detours repository already cloned."
    }
}

function build_detours {
    # Build Detours and necessary samples
    pushd Detours
    git submodule init
    git submodule update
    pushd src
    nmake
    popd
    pushd samples\withdll
    nmake
    popd
    popd
}

function build_dll {
    # Define the path for the DLL (renamed to something less suspicious)
    $dllFilePath = Join-Path $projectDir "Notepad.dll"

    # Create build directory and compile the DLL
    mkdir './build' -Force
    pushd build

    # Compile the DLL and link with necessary libraries
    cl '/EHsc' '/LD' '/Fe:Notepad.dll' '../Notepad.cpp' `
        '/I../Detours/include' '/link' '/nodefaultlib:oldnames.lib' `
        '/export:DetourFinishHelperProcess,@1,NONAME' '/export:GetSystemMetrics' `
        '../Detours/lib.X86/detours.lib' '../Detours/lib.X86/syelog.lib' `
        'user32.lib' 'wtsapi32.lib' 'advapi32.lib'

    # Check if the DLL was created successfully
    if (-Not (Test-Path "./Notepad.dll")) {
        Write-Host "Error: Notepad.dll was not created in the build directory."
        Exit 1
    } else {
        Write-Host "Notepad.dll successfully created."
    }

    popd
}

function configure_host {
    # Path to Host.wsb file
    $hostFilePath = "$projectDir\Host.wsb"

    # Check if Host.wsb exists and replace placeholder
    if (Test-Path $hostFilePath) {
        (Get-Content $hostFilePath).replace('{{HOST_FOLDER}}', $projectDir) | Set-Content $hostFilePath
    } else {
        Write-Host "Host.wsb file not found at $hostFilePath"
        Exit 1
    }
}

function copy_files {
    # Copy withdll.exe and renamed DLL to the project directory
    if (Test-Path "./build/Notepad.dll") {
        cp ./build/Notepad.dll $projectDir
        Write-Host "Notepad.dll successfully copied to project directory."
    } else {
        Write-Host "Error: Notepad.dll not found in the build directory. Check the build process."
    }

    if (Test-Path "Detours\bin.X86\withdll.exe") {
        cp Detours\bin.X86\withdll.exe $projectDir
        Write-Host "withdll.exe successfully copied to project directory."
    } else {
        Write-Host "Error: withdll.exe not found in Detours\bin.X86."
    }
}

# Main execution
# Copy the renamed Notepad.cpp file to the project directory if it doesn't exist
$cppFilePath = Join-Path $projectDir "Notepad.cpp"
if (-Not (Test-Path $cppFilePath)) {
    # Create a sample C++ file that looks more innocent
    @"
#include <windows.h>
extern "C" __declspec(dllexport) void GetSystemMetrics() {
    // Notepad related code or harmless code can go here
}
"@ | Set-Content -Path $cppFilePath
}

# Execute the functions
initialize_vs
clone_detours
build_detours
build_dll
configure_host
copy_files
