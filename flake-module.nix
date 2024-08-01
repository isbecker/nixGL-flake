{ self, config, lib, flake-parts-lib, nixGL, ... }:

let
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib)
    types;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, self', inputs', pkgs, system, ... }:
        let
          nixGLSubmodule = types.submodule {
            options = {
              prefix = lib.mkOption {
                type = types.str;
                default = "";
                example = lib.literalExpression
                  ''"''${nixGL.packages.x86_64-linux.nixGLIntel}/bin/nixGLIntel"'';
                description = ''
                  The nixGL command that `lib.nixGL.wrap` should wrap packages with.
                  This can be used to provide libGL access to applications on non-NixOS systems.

                  Wrap individual packages like so: `(config.lib.nixGL.wrap <package>)`. The returned package
                  can be used just like the original one, but will have access to libGL. If this option is empty (the default),
                  then `lib.nixGL.wrap` is a no-op. This is useful on NixOS, where the wrappers are unnecessary.
                '';
              };
            };
            config =
              let
                wrap = pkg:
                  if config.nixGL.prefix == "" then
                    pkg
                  else
                    pkg.overrideAttrs (old: {
                      name = "nixGL-${pkg.name}";

                      separateDebugInfo = false;
                      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ pkgs.makeWrapper ];
                      buildCommand = ''
                        set -eo pipefail

                        ${
                          lib.concatStringsSep "\n" (map (outputName: ''
                            echo "Copying output ${outputName}"
                            set -x
                            cp -rs --no-preserve=mode "${pkg.${outputName}}" "$out/${outputName}"
                            set +x
                          '') (old.outputs or [ "out" ]))
                        }

                        rm -rf $out/bin/*
                        shopt -s nullglob # Prevent loop from running if no files
                        for file in ${pkg.out}/bin/*; do
                          local prog="$(basename "$file")"
                          makeWrapper \
                            "${config.nixGL.prefix}" \
                            "$out/bin/$prog" \
                            --argv0 "$prog" \
                            --add-flags "$file"
                        done

                        # If .desktop files refer to the old package, replace the references
                        for dsk in "$out/share/applications"/*.desktop; do
                          if ! grep -q "${pkg.out}" "$dsk"; then
                            continue
                          fi
                          src="$(readlink "$dsk")"
                          rm "$dsk"
                          sed "s|${pkg.out}|$out|g" "$src" > "$dsk"
                        done

                        shopt -u nullglob # Revert nullglob back to its normal default state
                      '';
                    });
              in
              {
                wrap = wrap;
              };
          };
        in
        {
          options.nixGL = lib.mkOption {
            type = nixGLSubmodule;
            description = ''
              Configuration for nixGL wrapping.
            '';
          };
        });
  };
}
