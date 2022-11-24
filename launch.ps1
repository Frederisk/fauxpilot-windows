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
    [Switch][Alias('h')]$Help
)

if ($Help) {
    Get-Help -Name ($MyInvocation.MyCommand.Definition) -Full | Out-Host;
    exit 0;
}

# Read in .env file; error if not found
if (-not (Get-Item -Path '.env' -ErrorAction SilentlyContinue)) {
    Write-Warning -Message '.env not found, running setup.ps1' | Out-Null;
    & 'setup.ps1';
}

Write-Verbose -Message 'Read in .env file' | Out-Null;
Get-Content -Path '.env' -Encoding utf8NoBOM | ForEach-Object -Process {
    $name, $value = $_.Split('=');
    Write-Verbose -Message "Name: $name, Value: $value" | Out-Null;
    # Set-Variable -Name $name -Value $value;
    [Environment]::SetEnvironmentVariable($name, $value);
}

try {
    [ApplicationInfo]$docker = Get-Command -Name 'docker';
    Write-Verbose -Message 'up with docker compose';
    &$docker compose up -d --remove-orphans;
}
catch {
    Write-Verbose -Message $_.ToString();
    [ApplicationInfo]$dockerCompose = Get-Command -Name 'docker-compose';
    Write-Verbose -Message 'up with docker-compose';
    &$dockerCompose up -d --remove-orphans;
}
