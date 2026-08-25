final: prev: {
  bettercrewlink = let
    pname = "bettercrewlink";
    version = "3.1.4";
    src = prev.fetchurl {
      url = "https://github.com/OhMyGuus/BetterCrewLink/releases/download/v${version}/Better-CrewLink-${version}.AppImage";
      hash = "sha256-6OCYC/A8emhD8SFvUVZl9WubKUwHPCgQh4cowvPgV4c=";
    };
    appimageContents = prev.appimageTools.extractType2 { inherit pname version src; };
  in prev.appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
      install -Dm444 ${appimageContents}/bettercrewlink.desktop -t $out/share/applications
      install -Dm444 ${appimageContents}/bettercrewlink.png -t $out/share/pixmaps
      substituteInPlace $out/share/applications/bettercrewlink.desktop \
        --replace-quiet 'Exec=AppRun' 'Exec=${pname}'
    '';

    meta = with prev.lib; {
      description = "Proximity voice chat for Among Us";
      homepage = "https://bettercrewl.ink";
      license = licenses.gpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "bettercrewlink";
    };
  };
}
