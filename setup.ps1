using namespace System;
using namespace System.Management.Automation;
using namespace System.IO;

if (Get-Item -Path "config.env" -ErrorAction SilentlyContinue) {
    Write-Host @"
config.env already exists, skipping
Please delete config.env if you want to re-run this script
"@ | Out-Null;
    Exit 0;
}

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
[String]$model = switch ($modelNum) {
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

# Read number of GPUs
[Int32]$numGpus = Read-Host -Prompt "Enter number of GPUs [1]";
if ($numGpus -eq 0) {
    $numGpus = 1;
}

# Read model directory
[String]$modelDir = Read-Host -Prompt "Where do you want to save the model [$([Path]::Combine($pwd.Path, "models"))]?"
if ([String]::IsNullOrWhiteSpace($modelDir)) {
    $modelDir = ([Path]::Combine($pwd.Path, "models"));
}

# Write config.env
New-Item -Name "config.env" -ItemType File -Value @"
MODEL=$model
NUM_GPUS=$numGpus
MODEL_DIR=$modelDir
"@ | Out-Null;

if (Get-Item -Path ([Path]::Combine($modelDir, "$model-${numGpus}gpu")) -ErrorAction SilentlyContinue) {
    Write-Host @"
Converted model for $model-${numGpus}gpu already exists, skipping
Please delete $([Path]::Combine($modelDir, "$model-${numGpus}gpu")) if you want to re-convert it
"@ | Out-Null;
    Exit 0;
}

# Create model directory
New-Item -Path $modelDir -ItemType Directory -Force | Out-Null;

# For some of the models we can download it preconverted.
if ($numGpus -le 2) {
    Write-Host "Downloading the model from HuggingFace, this will take a while..." | Out-Null;
    [String]$scriptDir = $PSScriptRoot;
    [String]$dest = "$model-${numGpus}gpu";
    [String]$archive = ([Path]::Combine($modelDir, "$dest.tar.zst"));
    Copy-Item -Path ([Path]::Combine($scriptDir, 'converter', 'models', $dest)) -Destination $modelDir -Recurse | Out-Null;
    Invoke-WebRequest -Uri "https://huggingface.co/moyix/$model-gptj/resolve/main/$model-${numGpus}gpu.tar.zst" -OutFile $archive;

    if ($IsWindows -or ($null -eq $IsWindows)) {
        [ApplicationInfo]$7z = Get-Command -Name '7z' -ErrorAction SilentlyContinue;
        if (-not $7z) {
            $7z = Get-Command -Name "$env:ProgramFiles\7-Zip-Zstandard\7z.exe" -ErrorAction SilentlyContinue;
        }
        if (-not $7z) {
            $7z = Get-Command -Name "${env:ProgramFiles(x86)}\7-Zip-Zstandard\7z.exe";
        }
        # if(-not $7z){
        #     Write-Error -Message "Command 7z not found" -Category ObjectNotFound -TargetObject $7z;
        #     Exit 1;
        # }
        # Powershell will buffer the input to the second 7z process so can consume a lot of memory if your tar file is large.
        # https://stackoverflow.com/a/14699663/10135995
        [ApplicationInfo]$cmd = Get-Command -Name 'cmd';
        &$cmd /C "`"$($7z.Source)`" x $archive -so | `"$($7z.Source)`" x -aoa -si -ttar -o`"$modelDir`"";
    }
    elseif ($IsLinux -or $IsMacOS) {
        [ApplicationInfo]$bash = Get-Command -Name 'bash';
        &$bash -c "zstd -dc '$archive' | tar -xf - -C '$modelDir'";
    }
    else {
        Write-Host "Unknown OS. Please unzip $archive in the same folder.";
        Exit 0;
    }

    Remove-Item -Path $archive -Force;
}
else {
    Write-Host "Downloading and converting the model, this will take a while..."
    [ApplicationInfo]$docker = Get-Command -Name 'docker';
    &$docker run --rm -v ${modelDir}:/model -e MODEL=${model} -e NUM_GPUS=$numGpus moyix/model_converter:latest;
}
Write-Host "Done! Now run $([Path]::Combine('.', 'launch.ps1')) to start the FauxPilot server."
