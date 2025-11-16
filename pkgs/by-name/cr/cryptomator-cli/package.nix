{
  autoPatchelfHook,
  fetchFromGitHub,
  fuse3,
  glib,
  zulu25,
  lib,
  makeShellWrapper,
  maven,
  nix-update-script,
}:

let
  jdk = zulu25;
in
maven.buildMavenPackage rec {
  pname = "cryptomator-cli";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "cryptomator";
    repo = "cli";
    rev = version;
    hash = "sha256-rwARleKktGXmumIBmrPrfls4EywBqGBxOaB8/ka5ds0=";
  };

  mvnJdk = jdk;
  mvnParameters = "-Dmaven.test.skip=true";
  mvnHash = "sha256-54DT4C+WzyUBPxayA9YnB9I/Igd19iZygByUh5of51I=";

  preBuild = ''
    export APP_VERSION=${version}
    export SEMVER_STR=${version}
  '';

  # Based on the build_linux.sh script and jpackage configuration
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin/ $out/share/cryptomator-cli/libs/ $out/share/cryptomator-cli/mods/
    mkdir -p $out/share/bash-completion/completions/

    # Copy dependencies
    cp target/libs/* $out/share/cryptomator-cli/libs/
    cp target/mods/* target/cryptomator-cli-*.jar $out/share/cryptomator-cli/mods/

    # Copy bash completion script if it exists
    if [ -f target/cryptomator-cli_completion.sh ]; then
      cp target/cryptomator-cli_completion.sh $out/share/bash-completion/completions/cryptomator-cli
    fi

    # Determine native access package based on architecture
    NATIVE_ACCESS_PACKAGE="no.native.access.available"
    if [ "$(uname -m)" = "x86_64" ]; then
      NATIVE_ACCESS_PACKAGE="org.cryptomator.jfuse.linux.amd64"
    elif [ "$(uname -m)" = "aarch64" ]; then
      NATIVE_ACCESS_PACKAGE="org.cryptomator.jfuse.linux.aarch64"
    fi

    # Create wrapper script
    makeShellWrapper ${jdk}/bin/java $out/bin/${pname} \
      --add-flags "--enable-native-access=$NATIVE_ACCESS_PACKAGE,org.fusesource.jansi" \
      --add-flags "--class-path '$out/share/cryptomator-cli/libs/*'" \
      --add-flags "--module-path '$out/share/cryptomator-cli/mods'" \
      --add-flags "-Dfile.encoding='utf-8'" \
      --add-flags "-Dorg.cryptomator.cli.version='${version}'" \
      --add-flags "-Xss5m" \
      --add-flags "-Xmx256m" \
      --add-flags "--module org.cryptomator.cli/org.cryptomator.cli.CryptomatorCli" \
      --prefix PATH : "${
        lib.makeBinPath [
          jdk
          glib
        ]
      }" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ fuse3 ]}" \
      --set JAVA_HOME "${jdk.home}"

    runHook postInstall
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    jdk
    makeShellWrapper
  ];

  buildInputs = [
    fuse3
    glib
    jdk
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Command line program to access encrypted Cryptomator vaults";
    homepage = "https://github.com/cryptomator/cli";
    changelog = "https://github.com/cryptomator/cli/releases/tag/${version}";
    license = lib.licenses.agpl3Plus;
    mainProgram = "cryptomator-cli";
    maintainers = with lib.maintainers; [
      masrlinu
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # maven dependencies
    ];
  };
}
