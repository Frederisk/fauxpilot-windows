using namespace System;
using namespace System.Management.Automation;

# Read in config.env file; error if not found
if (-not (Get-Item -Path 'config.env' -ErrorAction SilentlyContinue)) {
    Write-Error "config.env not found, please run setup.ps1" | Out-Null;
    Exit 1;
}

Get-Content -Path 'config.env' | ForEach-Object -Process {
    $name, $value = $_.Split('=');
    Set-Variable -Name $name -Value $value;
    # [Environment]::SetEnvironmentVariable($name, $value);
}

[String]$dockerCompose = Get-Command -Name 'docker-compose' -ErrorAction SilentlyContinue;
if ($null -eq $dockerCompose) {
    $dockerCompose = 'docker compose';
}

[Environment]::SetEnvironmentVariable('NUM_GPUS', $NUM_GPUS);
[Environment]::SetEnvironmentVariable('MODEL_DIR', "$MODEL_DIR/$MODEL-${NUM_GPUS}gpu")
[Environment]::SetEnvironmentVariable('GPUS', 0..($NUM_GPUS - 1) -join ',');

&$dockerCompose up
