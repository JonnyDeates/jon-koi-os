# python.nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "langchain-env";

  buildInputs = [
      # Python base
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.python311Packages.setuptools
    pkgs.python311Packages.wheel

        # Compiler tools
    pkgs.gcc

        # Runtime libraries for numpy, moviepy, whisper, etc.
        pkgs.zlib
        pkgs.ffmpeg
        pkgs.libjpeg
        pkgs.freetype
        pkgs.libpng
        pkgs.pkg-config
        pkgs.libGL
        pkgs.xorg.libX11
        pkgs.glib
  ];
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.gcc.cc
        pkgs.zlib
        pkgs.ffmpeg
        pkgs.libjpeg
        pkgs.freetype
        pkgs.libpng
        pkgs.libGL
        pkgs.xorg.libX11
        pkgs.glib
  ];

  shellHook = ''
    echo "🔧 Setting up Python virtual environment..."

    if [ ! -d .venv ]; then
      python -m venv .venv
    fi

    source .venv/bin/activate

    pip install --upgrade pip

    pip install \
      langchain \
      langchain-community \
      langchain-ollama \
      chromadb \
      tiktoken \
      unstructured \
      moviepy \
      git+https://github.com/openai/whisper.git \
      opencv-python \
      pillow \
      openai \
      paramiko
  '';
}