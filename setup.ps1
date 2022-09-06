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
    [Alias('h', '?')]
    [Switch]$Help,
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
    [String]$ModelDir,
    [Switch]$Silent,
    [ValidateSet('NotDownload', 'NotRemove', 'NotUnzip', 'ForceCreate')]
    [String[]]$DebugMode
)

if ($Help) {
    Get-Help ($MyInvocation.MyCommand.Definition) -Full | Out-Host -Paging;
    exit 0;
}

# DEBUG: ForceCreate
if ((Get-Item -Path "config.env" -ErrorAction SilentlyContinue) -and (-not $DebugMode.Contains('ForceCreate'))) {
    Write-Host -Message @"
config.env already exists, skipping
Please delete config.env if you want to re-run this script
"@ | Out-Null;
    exit 0;
}

if ([String]::IsNullOrWhiteSpace($Model)) {
    if ($Silent) {
        $Model = 'codegen-6B-multi';
    }
    else {
        Write-Host -Message @"
[1] codegen-350M-mono (2GB total VRAM required; Python-only)
[2] codegen-350M-multi (2GB total VRAM required; multi-language)
[3] codegen-2B-mono (7GB total VRAM required; Python-only)
[4] codegen-2B-multi (7GB total VRAM required; multi-language)
[5] codegen-6B-mono (13GB total VRAM required; Python-only)
[6] codegen-6B-multi (13GB total VRAM required; multi-language)
[7] codegen-16B-mono (32GB total VRAM required; Python-only)
[8] codegen-16B-multi (32GB total VRAM required; multi-language)
"@ | Out-Null;
        # Read their choice
        [Int32]$modelNum = Read-Host -Prompt "Enter your choice [6]";
        # Convert model number to model name
        $Model = switch ($modelNum) {
            1 { "codegen-350M-mono"; }
            2 { "codegen-350M-multi"; }
            3 { "codegen-2B-mono"; }
            4 { "codegen-2B-multi"; }
            5 { "codegen-6B-mono"; }
            6 { "codegen-6B-multi"; }
            7 { "codegen-16B-mono"; }
            8 { "codegen-16B-multi"; }
            Default { "codegen-6B-multi"; }
        };
    }
}

if ($NumGpus -le 0) {
    if ($Silent) {
        $NumGpus = 1;
    }
    else {
        # Read number of GPUs
        [Int32]$NumGpus = Read-Host -Prompt "Enter number of GPUs [1]";
        if ($NumGpus -le 0) {
            $NumGpus = 1;
        }
    }
}

if ([String]::IsNullOrWhiteSpace($ModelDir)) {
    [String]$defaultDir = [Path]::Combine($pwd.Path, "models");
    if ($Silent) {
        $ModelDir = $defaultDir;
    }
    else {
        # Read model directory
        $ModelDir = Read-Host -Prompt "Where do you want to save the model [$([Path]::Combine($pwd.Path, "models"))]?";
        if ([String]::IsNullOrWhiteSpace($ModelDir)) {
            $ModelDir = $defaultDir;
        } else {
            $ModelDir = [Path]::GetFullPath($ModelDir);
        }
    }
}

# Write config.env
New-Item -Name "config.env" -ItemType File -Value @"
MODEL=$Model
NUM_GPUS=$NumGpus
MODEL_DIR=$ModelDir
"@ | Out-Null;

# DEBUG: ForceCreate
if ((Get-Item -Path ([Path]::Combine($ModelDir, "$Model-${NumGpus}gpu")) -ErrorAction SilentlyContinue) -and (-not $DebugMode.Contains('ForceCreate'))) {
    Write-Host -Message @"
Converted model for $Model-${NumGpus}gpu already exists, skipping
Please delete $([Path]::Combine($ModelDir, "$Model-${NumGpus}gpu")) if you want to re-convert it
"@ | Out-Null;
    exit 0;
}

# Create model directory
New-Item -Path $ModelDir -ItemType Directory -Force | Out-Null;

# For some of the models we can download it pre-converted.
if ($NumGpus -le 2) {
    Write-Host -Message "Downloading the model from HuggingFace, this will take a while..." | Out-Null;
    [String]$scriptDir = $PSScriptRoot;
    [String]$dest = "$Model-${NumGpus}gpu";
    [String]$archive = ([Path]::Combine($ModelDir, "$dest.tar.zst"));
    Copy-Item -Path ([Path]::Combine($scriptDir, 'converter', 'models', $dest)) -Destination $ModelDir -Recurse | Out-Null;

    # DEBUG: NotDownload
    if (-not $DebugMode.Contains('NotDownload')) {
        Invoke-WebRequest -Uri "https://huggingface.co/moyix/$Model-gptj/resolve/main/$Model-${NumGpus}gpu.tar.zst" -OutFile $archive | Out-Null;
    }
    else {
        Write-Host -Message "Download skipped: https://huggingface.co/moyix/$Model-gptj/resolve/main/$Model-${NumGpus}gpu.tar.zst" | Out-Null;
    }

    # DEBUG: NotUnzip
    if (-not $DebugMode.Contains('NotUnzip')) {
        if ($IsWindows -or ($null -eq $IsWindows)) {
            [ApplicationInfo]$7z = Get-Command -Name "$env:ProgramFiles\7-Zip-Zstandard\7z.exe" -ErrorAction SilentlyContinue;
            if (-not $7z) {
                $7z = Get-Command -Name "${env:ProgramFiles(x86)}\7-Zip-Zstandard\7z.exe" -ErrorAction SilentlyContinue;
            }
            if (-not $7z) {
                $7z = Get-Command -Name '7z';
            }
            # if(-not $7z){
            #     Write-Error -Message "Command 7z not found" -Category ObjectNotFound -TargetObject $7z;
            #     exit 1;
            # }
            # Powershell will buffer the input to the second 7z process so can consume a lot of memory if your tar file is large.
            # https://stackoverflow.com/a/14699663/10135995
            [ApplicationInfo]$cmd = Get-Command -Name 'cmd';
            &$cmd /C "`"$($7z.Source)`" x $archive -so | `"$($7z.Source)`" x -aoa -si -ttar -o`"$ModelDir`"";
        }
        elseif ($IsLinux -or $IsMacOS) {
            [ApplicationInfo]$bash = Get-Command -Name 'bash';
            &$bash -c "zstd -dc '$archive' | tar -xf - -C '$ModelDir'";
        }
        else {
            Write-Host -Message "Unknown OS. Please unzip $archive in the same folder by yourself." | Out-Null;
            exit 1;
        }
    }

    # DEBUG: NotUnzip
    if (-not $DebugMode.Contains('NotUnzip')) {
        Remove-Item -Path $archive -Force | Out-Null;
    }
}
else {
    Write-Host -Message "Downloading and converting the model, this will take a while..." | Out-Null;
    [ApplicationInfo]$docker = Get-Command -Name 'docker';
    &$docker run --rm -v ${ModelDir}:/model -e MODEL=$NumGpus -e NUM_GPUS=$NumGpus moyix/model_converter:latest;
}
Write-Host -Message "Done! Now run $([Path]::Combine('.', 'launch.ps1')) to start the FauxPilot server." | Out-Null;
