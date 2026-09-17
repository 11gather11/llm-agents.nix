{
  lib,
  flake,
  platformSource,
  stdenvNoCC,
  installShellFiles,
  formatelf,
  makeWrapper,
  gccForLibs,
  e2fsprogs,
  lz4,
  xxhash,
  zlib,
  zstd,
  versionCheckHook,
  mkUpdater,
}:
let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin";
    };
    urlTemplate = "https://github.com/docker/sbx-releases/releases/download/v{version}/DockerSandboxes-{platform}.tar.gz";
  };
in
stdenvNoCC.mkDerivation {
  pname = "docker-sbx";
  inherit (source) version src;

  strictDeps = true;
  __structuredAttrs = true;

  sourceRoot = if stdenvNoCC.hostPlatform.isDarwin then "." else null;

  nativeBuildInputs = [
    installShellFiles
    versionCheckHook
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
    formatelf
    makeWrapper
    e2fsprogs
  ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    lz4
    zlib
    zstd
    xxhash
    gccForLibs
  ];

  dontBuild = true;
  doInstallCheck = true;
  versionCheckProgramArg = "version";
  versionCheckKeepEnvironment = [ "HOME" ];
  preVersionCheck = ''
    export HOME=$TMPDIR
  '';

  installPhase =
    if stdenvNoCC.hostPlatform.isLinux then
      ''
        runHook preInstall

        PREFIX=$out bash ./install.sh

        wrapProgram $out/bin/sbx \
          --prefix PATH : ${lib.makeBinPath [ e2fsprogs ]}

        ${lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
          export HOME=$TMPDIR
          $out/bin/sbx completion bash > sbx.bash
          $out/bin/sbx completion fish > sbx.fish
          $out/bin/sbx completion zsh  > sbx.zsh
          installShellCompletion sbx.{bash,fish,zsh}
        ''}

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -pv $out
        cp -rv bin libexec $out

        installShellCompletion \
          --bash --name sbx.bash completions/bash/sbx \
          --zsh  --name _sbx     completions/zsh/_sbx \
          --fish --name sbx.fish completions/fish/sbx.fish

        runHook postInstall
      '';

  passthru.category = "Sandboxing & Isolation";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "docker";
        repo = "sbx-releases";
      };
    }
  );

  meta = {
    description = "Safe environments for agents";
    longDescription = ''
      Docker Sandboxes provides sandboxes with controlled access to your
      filesystem, network, and tools. This means your agents can work
      autonomously without putting your machine or data at risk.
    '';
    homepage = "https://docs.docker.com/reference/cli/sbx/";
    changelog = "https://github.com/docker/sbx-releases/releases/tag/v${source.version}";
    mainProgram = "sbx";
    platforms = source.platforms;
    license = flake.lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [
      lib.maintainers.skyesoss
    ];
  };
}
