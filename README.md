# FauxPilot Windows

For Linux or WLS2, click [here](https://github.com/moyix/fauxpilot).

This is an attempt to build a locally hosted version of [GitHub Copilot](https://copilot.github.com/). It uses the [SalesForce CodeGen](https://github.com/salesforce/CodeGen) models inside of NVIDIA's [Triton Inference Server](https://developer.nvidia.com/nvidia-triton-inference-server) with the [FasterTransformer backend](https://github.com/triton-inference-server/fastertransformer_backend/).

## Prerequisites

- Docker
- docker-compose (version >= 1.28)
- NVIDIA GPU (Compute Capability >= 7.0, That is TITAN V, RTX 20XX or newer)
- 7z-zstd

Note that the VRAM requirements listed by `setup.sh` are *total* -- if you have multiple GPUs, you can split the model across them. So, if you have two NVIDIA RTX 3080 GPUs, you *should* be able to run the 6B model by putting half on each GPU.

## Support and Warranty

lmao

## Setup

1. Install Docker and Docker Compose, The easiest way to install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
    > You can run `docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi` to test the CUDA working setup.
    > This should result in a console output shown below:
    >
    > ```plain
    > Fri Aug 26 20:20:28 2022
    > +-----------------------------------------------------------------------------+
    > | NVIDIA-SMI 515.65.01    Driver Version: 516.94       CUDA Version: 11.7     |
    > |-------------------------------+----------------------+----------------------+
    > | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
    > | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
    > |                               |                      |               MIG M. |
    > |===============================+======================+======================|
    > |   0  NVIDIA GeForce ...  On   | 00000000:2B:00.0  On |                  N/A |
    > | 41%   50C    P5    96W / 371W |  21480MiB / 24576MiB |      0%      Default |
    > |                               |                      |                  N/A |
    > +-------------------------------+----------------------+----------------------+
    >
    > +-----------------------------------------------------------------------------+
    > | Processes:                                                                  |
    > |  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
    > |        ID   ID                                                   Usage      |
    > |=============================================================================|
    > |    0   N/A  N/A        88      C   /tritonserver                   N/A      |
    > +-----------------------------------------------------------------------------+
    > ```

1. Install [7z-zstd](https://github.com/mcmilk/7-Zip-zstd).
    > As a suggestion, you can add the directory of 7z-zstd (usually `C:\Program Files\7-Zip-Zstandard`) to the `PATH`. Then restart Terminal and open `pwsh`, type `Get-Command -Name 7z` and press Enter. if everything is ok, you will see some information about `7z.exe` instead of errors or warnings message.
1. Run the setup script to choose a model to use. This will download the model from Huggingface and then convert it for use with FasterTransformer.

    ```plain
    $ .\setup.ps1
    [1] codegen-350M-mono (2GB total VRAM required; Python-only)
    [2] codegen-350M-multi (2GB total VRAM required; multi-language)
    [3] codegen-2B-mono (7GB total VRAM required; Python-only)
    [4] codegen-2B-multi (7GB total VRAM required; multi-language)
    [5] codegen-6B-mono (13GB total VRAM required; Python-only)
    [6] codegen-6B-multi (13GB total VRAM required; multi-language)
    [7] codegen-16B-mono (32GB total VRAM required; Python-only)
    [8] codegen-16B-multi (32GB total VRAM required; multi-language)
    Enter your choice [6]:
    Enter number of GPUs [1]:
    Where do you want to save the model [C:\Users\Frederisk\Documents\GitHub\fauxpilot\models]?:
    Downloading the model from HuggingFace, this will take a while...
    Done! Now run .\launch.ps1 to start the FauxPilot server.
    ```

1. Then you can just run `.\launch.ps1`. This process can take considerable amount of time to load. In general, It's already loaded when you see output like this:

    ```plain
    ......
    fauxpilot-triton-1         | I0803 01:51:04.740423 93 grpc_server.cc:4587] Started GRPCInferenceService at 0.0.0.0:8001
    fauxpilot-triton-1         | I0803 01:51:04.740608 93 http_server.cc:3303] Started HTTPService at 0.0.0.0:8000
    fauxpilot-triton-1         | I0803 01:51:04.781561 93 http_server.cc:178] Started Metrics Service at 0.0.0.0:8002
    ```

1. Enjoy!

## Copilot Plugin Support

Yes, it's possible. Please check [this issue](https://github.com/moyix/fauxpilot/issues/1).

## Acknowledgement

The code logic of this repository is derived from [moyix/fauxpilot](https://github.com/moyix/fauxpilot) and refactored by myself.
