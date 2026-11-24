{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  librsvg,
  chafa,
}:

stdenvNoCC.mkDerivation {
  pname = "svgview";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./svgview.py;
  };

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 svgview.py $out/libexec/svgview.py
    makeWrapper ${python3}/bin/python3 $out/bin/svgview \
      --add-flags $out/libexec/svgview.py \
      --prefix PATH : ${lib.makeBinPath [ librsvg chafa ]}

    # lot-map-term: open the live lot-map in its own kitty window.
    # Uses whatever kitty is on PATH so we don't pull in a second copy.
    cat > $out/bin/lot-map-term <<EOF
    #!${stdenvNoCC.shell}
    exec kitty --class lot-map --title lot-map $out/bin/svgview "\$@"
    EOF
    chmod +x $out/bin/lot-map-term
    runHook postInstall
  '';

  meta = {
    description = "Show an SVG in the terminal (kitty graphics) and redraw it live as the file changes";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "svgview";
  };
}
