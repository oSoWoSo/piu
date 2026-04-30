#!/usr/bin/env bats

FUNC_NAMES="search remove purge list list_files install update num_updates \
num_pkgs repo_update manual"

# brew stub
function brew () { echo $@; }

# uname stub
function uname () { echo "Darwin"; }

load ./piu

setup() {
  export -f brew
  export -f uname
  _ORIG_HOME="$HOME"
}

@test "[UTIL] 'not_implemented' shows error message and exits" {

  # TODO: Test the exit code. Will require integration of the bats-support and
  # bats-assert libraries

  we_did_not_implement_this() {
    not_implemented;
  }

  run we_did_not_implement_this

  [ "$output" == "'we_did_not_implement_this' not implemented yet!" ]
}


# Brew
########################################################################

@test "[BREW] implements the interface" {

 for func in ${FUNC_NAMES[@]};
 do
  declare -f -F "brew_$func";

  [ "$?" == "0" ];
 done
}

@test "[BREW] proxies the 'cask' argument to brew" {

  run ./piu install aPackage
  [ "$output" == "install aPackage" ]

  run ./piu cask install aPackage
  [ "$output" == "cask install aPackage" ]

  run ./piu install --cask aPackage
  [ "$output" == "install --cask aPackage" ]
}

# Apt
########################################################################

@test "[APT] implements the interface" {

 for func in ${FUNC_NAMES[@]};
 do
  declare -f -F "apt_$func";

  [ "$?" == "0" ];
 done
}

teardown() {
  unset -f brew
  unset -f uname
  # Restore HOME if it was changed
  if [[ -n "$_ORIG_HOME" ]]; then
    export HOME="$_ORIG_HOME"
    unset _ORIG_HOME
  fi
  # Restore Nix config variables to defaults
  export NIX_INSTALL_METHOD="auto"
  export NIX_FLAKES_ENABLED="auto"
  export NIX_CHANNEL="nixpkgs"
  export DEFAULT_PKGMAN=""
  # Clean up any temp dirs created by tests
  if [[ -n "$_TEST_HOME" && -d "$_TEST_HOME" ]]; then
    rm -rf "$_TEST_HOME"
    unset _TEST_HOME
  fi
}


# Nix
########################################################################

@test "[NIX] implements the interface" {

 for func in ${FUNC_NAMES[@]};
 do
  declare -f -F "nix_$func";

  [ "$?" == "0" ];
 done
}

@test "[NIX] __nix_detect_version returns version from nix-env" {
  function nix-env() { echo "nix-env (Nix) 2.18.1"; }
  export -f nix-env

  run __nix_detect_version
  [ "$status" -eq 0 ]
  [ "$output" == "2.18.1" ]

  unset -f nix-env
}

@test "[NIX] __nix_detect_version falls back to nix when nix-env unavailable" {
  function nix-env() { return 1; }
  function nix() { echo "nix (Nix) 2.20.0"; }
  export -f nix-env
  export -f nix

  run __nix_detect_version
  [ "$status" -eq 0 ]
  [ "$output" == "2.20.0" ]

  unset -f nix-env
  unset -f nix
}

@test "[NIX] __nix_detect_version returns empty when nix is not installed" {
  function nix-env() { return 1; }
  function nix() { return 1; }
  export -f nix-env
  export -f nix

  run __nix_detect_version
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  unset -f nix-env
  unset -f nix
}

@test "[NIX] __nix_version_ge returns 0 when current version meets requirement" {
  function __nix_detect_version() { echo "2.18.1"; }
  export -f __nix_detect_version

  __nix_version_ge "2.4"
  [ "$?" -eq 0 ]

  unset -f __nix_detect_version
}

@test "[NIX] __nix_version_ge returns 0 when current version equals requirement" {
  function __nix_detect_version() { echo "2.4"; }
  export -f __nix_detect_version

  __nix_version_ge "2.4"
  [ "$?" -eq 0 ]

  unset -f __nix_detect_version
}

@test "[NIX] __nix_version_ge returns non-zero when current version is older" {
  function __nix_detect_version() { echo "2.3.7"; }
  export -f __nix_detect_version

  run __nix_version_ge "2.4"
  [ "$status" -ne 0 ]

  unset -f __nix_detect_version
}

@test "[NIX] __nix_version_ge returns non-zero when nix is not installed" {
  function __nix_detect_version() { echo ""; }
  export -f __nix_detect_version

  run __nix_version_ge "2.4"
  [ "$status" -ne 0 ]

  unset -f __nix_detect_version
}

@test "[NIX] __nix_detect_flakes detects nix-command and flakes in user nix.conf" {
  _TEST_HOME=$(mktemp -d)
  mkdir -p "$_TEST_HOME/.config/nix"
  echo "experimental-features = nix-command flakes" > "$_TEST_HOME/.config/nix/nix.conf"

  # Export HOME into subshell so the function sees the right path
  export HOME="$_TEST_HOME"
  run __nix_detect_flakes
  [ "$status" -eq 0 ]
}

@test "[NIX] __nix_detect_flakes detects flakes listed before nix-command" {
  _TEST_HOME=$(mktemp -d)
  mkdir -p "$_TEST_HOME/.config/nix"
  echo "experimental-features = flakes nix-command" > "$_TEST_HOME/.config/nix/nix.conf"

  export HOME="$_TEST_HOME"
  run __nix_detect_flakes
  [ "$status" -eq 0 ]
}

@test "[NIX] __nix_detect_flakes returns non-zero when no config files exist and nix unavailable" {
  _TEST_HOME=$(mktemp -d)
  # No nix config files created; stub nix to fail
  function nix() { return 1; }
  export -f nix
  export HOME="$_TEST_HOME"

  run __nix_detect_flakes
  [ "$status" -ne 0 ]

  unset -f nix
}

@test "[NIX] __nix_get_install_method returns configured method when not auto" {
  export NIX_INSTALL_METHOD="nix-env"

  run __nix_get_install_method
  [ "$status" -eq 0 ]
  [ "$output" == "nix-env" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_get_install_method returns nix-profile when configured" {
  export NIX_INSTALL_METHOD="nix-profile"

  run __nix_get_install_method
  [ "$status" -eq 0 ]
  [ "$output" == "nix-profile" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_get_install_method returns flakes when configured" {
  export NIX_INSTALL_METHOD="flakes"

  run __nix_get_install_method
  [ "$status" -eq 0 ]
  [ "$output" == "flakes" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_get_install_method auto falls back to nix-env for old versions" {
  export NIX_INSTALL_METHOD="auto"
  function __nix_detect_version() { echo "2.3.7"; }
  export -f __nix_detect_version

  run __nix_get_install_method
  [ "$status" -eq 0 ]
  [ "$output" == "nix-env" ]

  unset -f __nix_detect_version
}

@test "[NIX] __nix_convert_package_name adds dot notation for nix-env" {
  export NIX_INSTALL_METHOD="nix-env"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "firefox"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs.firefox" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name adds hash notation for flakes" {
  export NIX_INSTALL_METHOD="flakes"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "firefox"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs#firefox" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name adds dot notation for nix-profile" {
  export NIX_INSTALL_METHOD="nix-profile"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "git"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs.git" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name passes through already-prefixed dot packages for nix-env" {
  export NIX_INSTALL_METHOD="nix-env"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "nixpkgs.firefox"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs.firefox" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name converts hash-format to dot-format for nix-env" {
  export NIX_INSTALL_METHOD="nix-env"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "nixpkgs#firefox"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs.firefox" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name converts dot-format to hash-format for flakes" {
  export NIX_INSTALL_METHOD="flakes"
  export NIX_CHANNEL="nixpkgs"

  run __nix_convert_package_name "nixpkgs.firefox"
  [ "$status" -eq 0 ]
  [ "$output" == "nixpkgs#firefox" ]

  export NIX_INSTALL_METHOD="auto"
}

@test "[NIX] __nix_convert_package_name respects custom NIX_CHANNEL" {
  export NIX_INSTALL_METHOD="nix-env"
  export NIX_CHANNEL="nixos-unstable"

  run __nix_convert_package_name "vim"
  [ "$status" -eq 0 ]
  [ "$output" == "nixos-unstable.vim" ]

  export NIX_INSTALL_METHOD="auto"
  export NIX_CHANNEL="nixpkgs"
}


# init_config
########################################################################

@test "[CONFIG] init_config creates config file when it does not exist" {
  _TEST_HOME=$(mktemp -d)
  export HOME="$_TEST_HOME"

  run init_config
  [ "$status" -eq 0 ]
  [ -f "$_TEST_HOME/.config/piu/piu.conf" ]
}

@test "[CONFIG] init_config reports success message on creation" {
  _TEST_HOME=$(mktemp -d)
  export HOME="$_TEST_HOME"

  run init_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"Configuration file created at:"* ]]
}

@test "[CONFIG] init_config exits with error when config already exists" {
  _TEST_HOME=$(mktemp -d)
  mkdir -p "$_TEST_HOME/.config/piu"
  touch "$_TEST_HOME/.config/piu/piu.conf"
  export HOME="$_TEST_HOME"

  run init_config
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
}

@test "[CONFIG] init_config creates config directory if missing" {
  _TEST_HOME=$(mktemp -d)
  # No .config/piu directory created
  export HOME="$_TEST_HOME"

  run init_config
  [ -d "$_TEST_HOME/.config/piu" ]
}

@test "[CONFIG] init_config copies piu.conf.example when available" {
  _TEST_HOME=$(mktemp -d)
  export HOME="$_TEST_HOME"

  run init_config
  [ "$status" -eq 0 ]
  # Verify created file contains NIX_CHANNEL (from example file)
  grep -q "NIX_CHANNEL" "$_TEST_HOME/.config/piu/piu.conf"
}

@test "[CONFIG] config file is loaded and sets NIX_CHANNEL from user config" {
  _TEST_HOME=$(mktemp -d)
  mkdir -p "$_TEST_HOME/.config/piu"
  echo 'NIX_CHANNEL="my-custom-channel"' > "$_TEST_HOME/.config/piu/piu.conf"

  # Source config manually the same way piu does
  PIU_CONFIG="$_TEST_HOME/.config/piu/piu.conf"
  source "$PIU_CONFIG"

  [ "$NIX_CHANNEL" == "my-custom-channel" ]

  NIX_CHANNEL="nixpkgs"
}

@test "[CONFIG] config file is loaded and sets DEFAULT_PKGMAN" {
  _TEST_HOME=$(mktemp -d)
  mkdir -p "$_TEST_HOME/.config/piu"
  echo 'DEFAULT_PKGMAN="nix"' > "$_TEST_HOME/.config/piu/piu.conf"

  PIU_CONFIG="$_TEST_HOME/.config/piu/piu.conf"
  source "$PIU_CONFIG"

  [ "$DEFAULT_PKGMAN" == "nix" ]

  DEFAULT_PKGMAN=""
}

@test "[CONFIG] piu.conf.example contains all required variables" {
  local example_file
  example_file="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/piu.conf.example"

  [ -f "$example_file" ]
  grep -q "DEFAULT_PKGMAN" "$example_file"
  grep -q "NIX_INSTALL_METHOD" "$example_file"
  grep -q "NIX_FLAKES_ENABLED" "$example_file"
  grep -q "NIX_SCOPE" "$example_file"
  grep -q "NIX_CHANNEL" "$example_file"
}

@test "[CONFIG] piu.conf.example DEFAULT_PKGMAN defaults to empty string" {
  local example_file
  example_file="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/piu.conf.example"

  grep -q 'DEFAULT_PKGMAN=""' "$example_file"
}

@test "[CONFIG] piu.conf.example NIX_INSTALL_METHOD defaults to auto" {
  local example_file
  example_file="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/piu.conf.example"

  grep -q 'NIX_INSTALL_METHOD="auto"' "$example_file"
}

@test "[CONFIG] piu.conf.example NIX_FLAKES_ENABLED defaults to auto" {
  local example_file
  example_file="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/piu.conf.example"

  grep -q 'NIX_FLAKES_ENABLED="auto"' "$example_file"
}


# Distro-specific fixes
########################################################################

@test "[DNF] dnf_manual is defined" {
  declare -f -F "dnf_manual"
  [ "$?" == "0" ]
}

@test "[ZYPPER] zypper_list_files is defined" {
  declare -f -F "zypper_list_files"
  [ "$?" == "0" ]
}

@test "[ZYPPER] zypper_num_pkgs is defined (typo fix from zyyper_num_pkgs)" {
  declare -f -F "zypper_num_pkgs"
  [ "$?" == "0" ]
}

@test "[ZYPPER] zyyper_num_pkgs (old typo) is NOT defined" {
  # Regression: the old misspelled name should not exist
  declare -f -F "zyyper_num_pkgs"
  [ "$?" != "0" ]
}

@test "[ZYPPER] implements the interface" {

 for func in ${FUNC_NAMES[@]};
 do
  declare -f -F "zypper_$func";

  [ "$?" == "0" ];
 done
}

@test "[DNF] implements the interface" {

 for func in ${FUNC_NAMES[@]};
 do
  declare -f -F "dnf_$func";

  [ "$?" == "0" ];
 done
}
