#!/bin/sh

# Description: Install and/or update aws cli on Linux or Mac
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# Check latest version release notes:
#   https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
# Author: Chuck Nemeth

#######################
# VARIABLES
#######################
awsdir="$HOME/.local/aws-cli"
awsver="$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"
bindir="$HOME/.local/bin"
os="$(uname -s)"
tmpdir="$(mktemp -d /tmp/aws.XXXXXXXX)"


#######################
# OS CHECK
#######################
case "${os}" in
  "Darwin")
    installer="AWSCLIV2.pkg"
    awsurl="https://awscli.amazonaws.com/AWSCLIV2.pkg"
    ;;
  "Linux")
    installer="awscliv2.zip"
    awsurl="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    sigurl="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig"
    sigfile="awscliv2.sig"
    gpg_key="FB5DB77FD5C118B80511ADA8A6310ACC4672475C"
    ;;
  *)
    printf '%s\n' "Unsupported OS. Exiting"
    exit 1
esac


#######################
# PATH CHECK
#######################
case :$PATH: in
  *:"${bindir}":*)  ;;  # do nothing
  *)
    printf '%s\n' "ERROR ${bindir} was not found in \$PATH!"
    printf '%s\n' "Add ${bindir} to PATH or select another directory to install to"
    exit 1
    ;;
esac

if [ -d "${tmpdir}" ]; then
  cd "${tmpdir}" || exit
else
  printf '%s\n' "${tmpdir} doesn't exist."
  exit 1
fi


#######################
# VERSION CHECK
#######################
printf '%s\n' "Downloading CHANGELOG.rst from aws GitHub"
curl -s -O https://raw.githubusercontent.com/aws/aws-cli/v2/CHANGELOG.rst

case "${os}" in
  "Darwin")
    available="$(< CHANGELOG.rst grep '^\d' | head -n1)"
    ;;
  "Linux")
    available="$(< CHANGELOG.rst grep -P '^\d' | head -n1)"
    ;;
esac

if [ "${available}" = "${awsver}" ]; then
  printf '%s\n' "Already using latest version. Exiting."
  cd && rm -rf "${tmpdir}"
  exit
else
  printf '%s\n' "Installed Verision: ${awsver}"
  printf '%s\n' "Latest Version: ${available}"
fi


#######################
# DOWNLOAD
#######################
if [ -f "${installer}" ]; then
  rm -f "${installer}"
fi

printf '%s\n' "Downloading aws-cli installer"
curl -s "${awsurl}" -o "${installer}"

if [ "${os}" = "Linux" ]; then
  printf '%s\n' "Downloading aws-cli installer signature file"
  if ! gpg -k "${gpg_key}"; then
    printf '%s\n' "AWS GPG Key not found"
    printf '%s\n' "Get it from here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
  else
    curl -s "${sigurl}" -o "${sigfile}"
  fi
fi


#######################
# PREPARE
#######################
if [ ! -d "${bindir}" ]; then
  printf '%s\n' "Creating ${bindir}"
  mkdir -p "${bindir}"
fi

printf '%s\n' "Removing old version"
if [ -d "${awsdir}" ]; then
  rm -f "${bindir}/aws"
  rm -f "${bindir}/aws_completer"
  rm -rf "${awsdir}"
fi


#######################
# INSTALL
#######################
printf '%s\n' "Installing new version"
case "${os}" in
  "Darwin")
      printf '%s\n' "Creating installation config file"
      cat << EOF > choices.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key>
      <string>customLocation</string>
      <key>attributeSetting</key>
      <string>/Users/$(whoami)/.local/</string>
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

      printf '%s\n' "Creating symlinks"
      ln -s "${awsdir}/aws" "${bindir}/aws"
      ln -s "${awsdir}/aws_completer" "${bindir}/aws_completer"
      ;;
  "Linux")
      if gpg --verify "${sigfile}" "${installer}"; then
          unzip -q "${installer}"
          ./aws/install --bin-dir "${bindir}" --install-dir "${awsdir}"
      else
          printf '%s\n' "File failed GPG verification. Exiting."
          exit 1
      fi
      ;;
esac


#######################
# VERSION CHECK
#######################
printf '%s\n' "Old Version: ${awsver}"
printf '%s\n' "Installed Version: $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"


#######################
# CLEAN UP
#######################
printf "Would you like to delete the install files? (Yy/Nn) "
read -r choice
case "${choice}" in
  [yY]|[yY]es)
    printf '%s\n' "Cleaning up install files"
    cd ../ && rm -rf "${tmpdir}"
    ;;
  *)
    printf '%s\n' "Exiting without deleting files from ${tmpdir}"
    exit 0
    ;;
esac

# vim: ft=sh ts=2 sts=2 sw=2 sr et