#!/usr/bin/env -S pwsh -nop
#requires -version 5

<#PSScriptInfo
.VERSION 0.0.1
.GUID
.AUTHOR Rowe Wilson Frederisk Holme
.PROJECTURI https://github.com/Frederisk/fauxpilot-windows
.COMPANYNAME
.COPYRIGHT
.TAGS
.LICENSEURI https://github.com/Frederisk/fauxpilot-windows/blob/main/LICENSE.txt
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    fauxpilot-windows-setup - Configure and generate fauxpilot-windows files.
.DESCRIPTION

.PARAMETER Help
    Display the full help message.
.PARAMETER Model
    Specify the codegen model to use.
.PARAMETER NumGpus
    Set the number of GPUs in your device.
.PARAMETER ApiExternalPort
    Set the port which Fauxpilot used.
.PARAMETER TritonHost
    Set the Host name which Triton used.
.PARAMETER TritonPort
    Set the port which Triton used.
.PARAMETER Launch
    Launch docker after all done.
.PARAMETER ModelDir
    Determines where to store model files.
.PARAMETER Silent
    Silence the setup process. All parameters will be set to default values.
.PARAMETER DebugMode
    Some switches for testing and debugging.
.INPUTS
    System.String
.OUTPUTS
    System.Object
.NOTES

#>

using namespace System;
using namespace System.Management.Automation;
using namespace System.IO;

[CmdletBinding()]
param (
    [Switch][Alias('h')]$Help,
    [ValidateSet(
        'codegen-350M-mono',
        'codegen-350M-multi',
        'codegen-2B-mono',
        'codegen-2B-multi',
        'codegen-6B-mono',
        'codegen-6B-multi',
        'codegen-16B-mono',
        'codegen-16B-multi')]
    [String]$Model,
    [ValidateRange(1, [Int32]::MaxValue)]
    [Int32]$NumGpus,
    [ValidateRange(0, 65535)]
    [Int32]$ApiExternalPort,
    [String]$TritonHost,
    [ValidateRange(0, 65535)]
    [Int32]$TritonPort,
    [String]$ModelDir,
    [Switch]$Silent,
    [Switch]$Launch,
    [ValidateSet('NotRemove', 'ForceDownload')]
    [String[]]$DebugMode
)

if ($Help) {
    Get-Help -Name ($MyInvocation.MyCommand.Definition) -Full | Out-Host;
    exit 0;
}

if ($null -eq $DebugMode) {
    $DebugMode = @();
}

[String]$defaultDir = [Path]::Combine($pwd.Path, 'models');

if ($Silent) {
    Remove-Item -Path '.env' -Force -ErrorAction SilentlyContinue | Out-Null;
    if ([String]::IsNullOrWhiteSpace($Model)) {
        $Model = 'codegen-6B-multi';
    }
    if ($NumGpus -le 0) {
        $NumGpus = 1;
    }
    if ($ApiExternalPort -le 0) {
        $ApiExternalPort = 5000;
    }
    if ([String]::IsNullOrWhiteSpace($TritonHost)) {
        $TritonHost = 'triton';
    }
    if ($TritonPort -le 0) {
        $TritonPort = 8001;
    }
    if ([String]::IsNullOrWhiteSpace($ModelDir)) {
        $ModelDir = $defaultDir;
    }
}

if (Get-Item -Path '.env' -ErrorAction SilentlyContinue) {
    [String]$delete = Read-Host -Prompt '.env already exists, do you want to delete .env and recreate it? [y/n]';
    if ($delete -like 'y') {
        Write-Host -Object 'Deleting .env' | Out-Null;
        Remove-Item -Path '.env' -Force | Out-Null;
    }
    else {
        Write-Host -Object 'Exiting' | Out-Null;
        exit 0;
    }
}

if ([String]::IsNullOrWhiteSpace($Model)) {
    Write-Host -Object @'
Models available:
[1] codegen-350M-mono (2GB total VRAM required; Python-only)
[2] codegen-350M-multi (2GB total VRAM required; multi-language)
[3] codegen-2B-mono (7GB total VRAM required; Python-only)
[4] codegen-2B-multi (7GB total VRAM required; multi-language)
[5] codegen-6B-mono (13GB total VRAM required; Python-only)
[6] codegen-6B-multi (13GB total VRAM required; multi-language)
[7] codegen-16B-mono (32GB total VRAM required; Python-only)
[8] codegen-16B-multi (32GB total VRAM required; multi-language)
'@ | Out-Null;
    # Read their choice
    [Int32]$modelNum = Read-Host -Prompt 'Enter your choice [6]';
    # Convert model number to model name
    $Model = switch ($modelNum) {
        1 { 'codegen-350M-mono'; }
        2 { 'codegen-350M-multi'; }
        3 { 'codegen-2B-mono'; }
        4 { 'codegen-2B-multi'; }
        5 { 'codegen-6B-mono'; }
        6 { 'codegen-6B-multi'; }
        7 { 'codegen-16B-mono'; }
        8 { 'codegen-16B-multi'; }
        Default { 'codegen-6B-multi'; }
    };
}

# Read number of GPUs
if ($NumGpus -le 0) {
    # Read number of GPUs
    $NumGpus = Read-Host -Prompt 'Enter number of GPUs [1]';
    if ($NumGpus -le 0) {
        $NumGpus = 1;
    }
}

if ($ApiExternalPort -le 0) {
    $ApiExternalPort = Read-Host -Prompt 'External port for the API [5000]';
    if ($ApiExternalPort -le 0) {
        $ApiExternalPort = 5000;
    }
}

if ([String]::IsNullOrWhiteSpace($TritonHost)) {
    $TritonHost = Read-Host -Prompt 'Address for Triton [triton]';
    if ([String]::IsNullOrWhiteSpace($TritonHost)) {
        $TritonHost = 'triton';
    }
}

if ($TritonPort -le 0) {
    $TritonPort = Read-Host -Prompt 'Port of Triton host [8001]';
    if ($TritonPort -le 0) {
        $TritonPort = 8001;
    }
}

if ([String]::IsNullOrWhiteSpace($ModelDir)) {
    # Read model directory
    $ModelDir = Read-Host -Prompt "Where do you want to save the model [$([Path]::Combine($pwd.Path, 'models'))]?";
    if ([String]::IsNullOrWhiteSpace($ModelDir)) {
        $ModelDir = $defaultDir;
    }
    else {
        $ModelDir = [Path]::GetFullPath($ModelDir);
    }
}

Write-Verbose -Message 'Write .env file' | Out-Null;
New-Item -Name '.env' -ItemType File -Value @"
MODEL=$Model
NUM_GPUS=$NumGpus
MODEL_DIR=$ModelDir/$Model-${NumGpus}gpu
API_EXTERNAL_PORT=$ApiExternalPort
TRITON_HOST=$TritonHost
TRITON_PORT=$TritonPort
GPUS=$(0..($NumGpus - 1) -join ',')
"@ | Out-Null;

[Boolean]$download = $false;
# DEBUG: ForceDownload
if ((Get-Item -Path ([Path]::Combine($ModelDir, "$Model-${NumGpus}gpu") -and (-not $DebugMode.Contains('ForceDownload')) -and (-not $Silent)) -ErrorAction SilentlyContinue)) {
    Write-Host -Object 'Model $ModelDir/$Model-${NumGpus}gpu already exists.'
    [String]$reuse = Read-Host -Prompt 'Do you want to re-use it? [y/n]';
    if (-not $reuse -like 'y') {
        $download = $true;
    }
}
else {
    $download = $true;
}

if ($download) {
    # Create model directory
    New-Item -Path $ModelDir -ItemType Directory -Force | Out-Null;
    # For some of the models we can download it pre-converted.
    if ($NumGpus -le 2) {
        Write-Host -Object 'Downloading the model from HuggingFace, this will take a while...' | Out-Null;
        [String]$scriptDir = $PSScriptRoot;
        [String]$dest = "$Model-${NumGpus}gpu";
        [String]$archive = ([Path]::Combine($ModelDir, "$dest.tar.zst"));
        Copy-Item -Path ([Path]::Combine($scriptDir, 'converter', 'models', $dest)) -Destination $ModelDir -Recurse | Out-Null;

        if ($PSVersionTable.PSVersion.Major -lt 6) {
            Write-Verbose -Message @"
Progress bar can significantly impact cmdlet performance.
See: https://github.com/PowerShell/PowerShell/issues/2138.
Set `$ProgressPreference as SilentlyContinue to Disable it.
"@ | Out-Null;
            $ProgressPreference = 'SilentlyContinue';
        }
        [String]$downloadUri = "https://huggingface.co/moyix/$Model-gptj/resolve/main/$Model-${NumGpus}gpu.tar.zst";
        Write-Verbose -Message "Download Uri: $downloadUri" | Out-Null;
        Invoke-WebRequest -Uri $downloadUri -OutFile $archive | Out-Null;

        if ($IsWindows -or ($null -eq $IsWindows)) {
            Write-Verbose -Message 'System Type: Windows' | Out-Null;
            [ApplicationInfo]$7z = Get-Command -Name "$env:ProgramFiles\7-Zip-Zstandard\7z.exe" -ErrorAction SilentlyContinue;
            if (-not $7z) {
                $7z = Get-Command -Name "${env:ProgramFiles(x86)}\7-Zip-Zstandard\7z.exe" -ErrorAction SilentlyContinue;
            }
            if (-not $7z) {
                $7z = Get-Command -Name '7z';
            }
            # Powershell will buffer the input to the second 7z process so can consume a lot of memory if your tar file is large.
            # https://stackoverflow.com/a/14699663/10135995
            [ApplicationInfo]$cmd = Get-Command -Name 'cmd';
            Write-Verbose -Message 'Unzipping...' | Out-Null;
            &$cmd /C "`"$($7z.Source)`" x $archive -so | `"$($7z.Source)`" x -aoa -si -ttar -o`"$ModelDir`"";
        }
        elseif ($IsLinux -or $IsMacOS) {
            Write-Verbose -Message 'System Type: Linux or MacOS' | Out-Null;
            [ApplicationInfo]$bash = Get-Command -Name 'bash';
            &$bash -c "zstd -dc '$archive' | tar -xf - -C '$ModelDir'";
        }
        else {
            Write-Host -Object "Unknown OS. Please unzip $archive in the same folder by yourself." | Out-Null;
            exit 1;
        }

        if (-not $DebugMode.Contains('NotRemove')) {
            Write-Verbose -Message 'DEBUG: NotRemove' | Out-Null;
            Remove-Item -Path $archive -Force | Out-Null;
        }
    }
    else {
        Write-Host -Object 'Downloading and converting the model, this will take a while...' | Out-Null;
        [ApplicationInfo]$docker = Get-Command -Name 'docker';
        &$docker run --rm -v ${ModelDir}:/model -e MODEL=$NumGpus -e NUM_GPUS=$NumGpus moyix/model_converter:latest;
    }
}

if ($Launch) {
    & 'launch.ps1';
}
elseif ($Silent) {
    Write-Host -Object "Done! Now run $([Path]::Combine('.', 'launch.ps1')) to start the FauxPilot server." | Out-Null;
}
else {
    [String]$run = Read-Host -Prompt 'Config complete, do you want to run FauxPilot? [y/n]';
    if ($run -like 'y') {
        & 'launch.ps1';
    }
    else {
        Write-Host -Object 'You can run $([Path]::Combine('.', 'launch.ps1')) to start the FauxPilot server.' | Out-Null;
    }
}
