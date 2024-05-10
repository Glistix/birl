let
  inherit (builtins.import ../gleam_stdlib/gleam/option.nix) None;

  now = {}: 1000 * 1000 * builtins.currentTime or 0;

  monotonic_now = now;

  local_offset = {}: 0;

  local_timezone = {}: None;

in { inherit now monotonic_now local_offset local_timezone; }
