#!/bin/sh

# Description: Install and/or update aws cli on Linux or Mac
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# Check latest version release notes:
#   https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
# Author: Chuck Nemeth

# Colored output
code_grn() { tput setaf 2; printf '%s\n' "${1}"; tput sgr0; }
code_red() { tput setaf 1; printf '%s\n' "${1}"; tput sgr0; }
code_yel() { tput setaf 3; printf '%s\n' "${1}"; tput sgr0; }

# Define function to delete temporary install files
clean_up() {
  printf '%s\n' "[INFO] Cleaning up install files"
  cd && rm -rf "${tmp_dir}"
}

# Variables
bin_dir="$HOME/.local/bin"
src_dir="$HOME/.local/src"
aws_dir="${src_dir}/aws-cli"
os="$(uname -s)"

if command -v aws >/dev/null 2>&1; then
  aws_installed_version="$(aws --version | awk -F' |/' '{print $2}')"
else
  aws_installed_version="Not Installed"
fi

# OS Check
case "${os}" in
  "Darwin")
    installer="AWSCLIV2.pkg"
    awsurl="https://awscli.amazonaws.com/AWSCLIV2.pkg"
    ;;
  "Linux")
    installer="awscliv2.zip"
    awsurl="https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
    sigurl="https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip.sig"
    sigfile="awscliv2.sig"
    gpg_key="FB5DB77FD5C118B80511ADA8A6310ACC4672475C"
    if ! command -v unzip; then code_red "[ERROR] unzip not found. Please install and try again."; exit 1; fi
    ;;
  *)
    code_red "[ERROR] Unsupported OS. Exiting"
    exit 1
esac

# PATH Check
case :$PATH: in
  *:"${bin_dir}":*)  ;;  # do nothing
  *)
    code_red "[ERROR] ${bin_dir} was not found in \$PATH!"
    printf '%s\n' "Add ${bin_dir} to PATH or select another directory to install to"
    exit 1
    ;;
esac

# Run clean_up function on exit
trap clean_up EXIT

# Create temp directory
tmp_dir="$(mktemp -d /tmp/aws.XXXXXXXX)"
cd "${tmp_dir}" || { code_red "[ERROR] ${tmp_dir} doesn't exist." &&  exit 1; }

# Version Check
curl -s -O https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst

case "${os}" in
  "Darwin")
    available="$(< CHANGELOG.rst grep '^\d' | head -n1)"
    ;;
  "Linux")
    available="$(< CHANGELOG.rst grep -P '^\d' | head -n1)"
    ;;
esac

if [ "${available}" = "${aws_installed_version}" ]; then
  printf '%s\n' "Installed Verision: ${aws_installed_version}"
  printf '%s\n' "Latest Version: ${available}"
  code_yel "[INFO] Already using latest version. Exiting."
  exit
else
  printf '%s\n' "Installed Verision: ${aws_installed_version}"
  printf '%s\n' "Latest Version: ${available}"
fi

# Download
if [ -f "${installer}" ]; then
  rm -f "${installer}"
fi

printf '%s\n' "[INFO] Downloading aws-cli installer"
curl -s "${awsurl}" -o "${installer}"

if [ "${os}" = "Linux" ]; then
  printf '%s\n' "[INFO] Downloading aws-cli installer signature file"
  if ! gpg -k "${gpg_key}"; then
    code_red "[ERROR] AWS GPG Key not found"
    printf '%s\n' "Get it from here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
  else
    curl -s "${sigurl}" -o "${sigfile}"
  fi
fi

# Prepare
[ ! -d "${bin_dir}" ] && install -m 0700 -d "${bin_dir}"
[ ! -d "${src_dir}" ] && install -m 0700 -d "${src_dir}"

printf '%s\n' "[INFO] Removing old version"
if [ -d "${aws_dir}" ]; then
  rm -f "${bin_dir}/aws"
  rm -f "${bin_dir}/aws_completer"
  rm -rf "${aws_dir}"
fi

# Install
printf '%s\n' "[INFO] Installing new version"
case "${os}" in
  "Darwin")
      printf '%s\n' "[INFO] Creating installation config file"
      cat << EOF > choices.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key>
      <string>customLocation</string>
      <key>attributeSetting</key>
      <string>${src_dir}</string>
      <key>choiceIdentifier</key>
      <string>default</string>
    </dict>
  </array>
</plist>
EOF
      if [ -f "${installer}" ]; then
          installer -pkg "${installer}" \
                    -target CurrentUserHomeDirectory \
                    -applyChoiceChangesXML choices.xml
      fi

      printf '%s\n' "[INFO] Creating symlinks"
      ln -s "${aws_dir}/aws" "${bin_dir}/aws"
      ln -s "${aws_dir}/aws_completer" "${bin_dir}/aws_completer"
      ;;
  "Linux")
      if gpg --verify "${sigfile}" "${installer}"; then
          unzip -q "${installer}"
          ./aws/install --bin-dir "${bin_dir}" --install-dir "${aws_dir}"
      else
          code_red "[ERROR] File failed GPG verification. Exiting."
          exit 1
      fi
      ;;
esac

# Version Check
code_grn "Old Version: ${aws_installed_version}"
code_grn "Installed Version: $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"

# vim: ft=sh ts=2 sts=2 sw=2 sr et
