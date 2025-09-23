{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  python = pkgs.python311;
in
pkgs.mkShell {
  packages = with pkgs; [
    python
    python.pkgs.pip
    ffmpeg
    sox
    libsndfile
    git
    zlib
    glibc
    stdenv.cc.cc
    rocmPackages.rocm-smi
    rocmPackages.clr
  ];

  shellHook = ''
    export PYTHONNOUSERSITE=1

    # ROCm environment for RDNA3 (gfx1100)
    export ROCM_PATH=${pkgs.rocmPackages.clr}
    export HIP_VISIBLE_DEVICES=0
    export HSA_OVERRIDE_GFX_VERSION=11.0.0
    export HCC_AMDGPU_TARGET=gfx1100x
    export PYTORCH_ROCM_ARCH=gfx1100

    if [ ! -d .venv ]; then
      ${python}/bin/python -m venv .venv
    fi
    . .venv/bin/activate

    echo "✅ ROCm dev shell ready."
    pip install -U pip wheel setuptools
    pip install --index-url https://download.pytorch.org/whl/rocm6.0
    pip install torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1
    pip install transformers accelerate soundfile numpy
  '';
}
