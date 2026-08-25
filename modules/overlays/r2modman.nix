final: prev: {
  r2modman = prev.r2modman.overrideAttrs (oldAttrs: rec {
    version = "3.2.18";

    src = prev.fetchFromGitHub {
      owner = "ebkr";
      repo = "r2modmanPlus";
      tag = "v${version}";
      hash = "sha256-QGs3kF2GkHlISmRb0cIYOKts1b1RvBj5qkc2cUPawwE=";
    };

    missingHashes = ./r2modman-missing-hashes.json;

    offlineCache = prev.yarn-berry.fetchYarnBerryDeps {
      inherit src missingHashes;
      inherit (oldAttrs) patches;
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-bEhvT7eLBdAHkml5KC0Y75jxMEdWtLNvQenfZXUc2NU=";
    };
  });
}
