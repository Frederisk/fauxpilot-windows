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
    fauxpilot-windows-launch - Start fauxpilot in Windows.
.DESCRIPTION

.PARAMETER Help
    Display the full help message.
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
    [Switch][Alias('h', '?')]$Help
)

if ($Help) {
    Get-Help ($MyInvocation.MyCommand.Definition) -Full | Out-Host -Paging;
    exit 0;
}

# Read in config.env file; error if not found
if (-not (Get-Item -Path 'config.env' -ErrorAction SilentlyContinue)) {
    Write-Error -Message "config.env not found, please run setup.ps1" | Out-Null;
    exit 1;
}

Write-Verbose -Message 'Read in config.env file' | Out-Null;
Get-Content -Path 'config.env' -Encoding utf8NoBOM | ForEach-Object -Process {
    $name, $value = $_.Split('=');
    Write-Verbose -Message "Name: $name, Value: $value" | Out-Null;
    Set-Variable -Name $name -Value $value;
    # [Environment]::SetEnvironmentVariable($name, $value);
}

[Environment]::SetEnvironmentVariable('NUM_GPUS', $NUM_GPUS) | Out-Null;
Write-Verbose -Message "`$env:NUM_GPUS=$env:NUM_GPUS" | Out-Null;
[Environment]::SetEnvironmentVariable('MODEL_DIR', ([Path]::Combine("$MODEL_DIR", "$MODEL-${NUM_GPUS}gpu"))) | Out-Null;
Write-Verbose -Message "`$env:MODEL_DIR=$env:MODEL_DIR" | Out-Null;
[Environment]::SetEnvironmentVariable('GPUS', 0..($NUM_GPUS - 1) -join ',') | Out-Null;
Write-Verbose -Message "`$env:GPUS=$env:GPUS" | Out-Null;

[ApplicationInfo]$dockerCompose = Get-Command -Name 'docker-compose' -ErrorAction SilentlyContinue;
if ($null -ne $dockerCompose) {
    Write-Verbose -Message 'up with docker-compose';
    &$dockerCompose up
}
else {
    Write-Verbose -Message 'up with docker compose';
    [ApplicationInfo]$docker = Get-Command -Name 'docker';
    &$docker compose up
}
