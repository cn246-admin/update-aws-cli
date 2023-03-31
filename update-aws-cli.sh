#!/bin/sh

# Description: Install and/or update aws cli on Linux or Mac
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
# Check latest version release notes:
#   https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
# Author: Chuck Nemeth

#######################
# VARIABLES
#######################
bin_dir="$HOME/.local/bin"
src_dir="$HOME/.local/src"
aws_dir="${src_dir}/aws-cli"
os="$(uname -s)"
tmp_dir="$(mktemp -d /tmp/aws.XXXXXXXX)"

if command -v yq >/dev/null; then
  aws_installed_version="$(aws --version | awk -F' |/' '{print $2}')"
else
  aws_installed_version="Not Installed"
fi

#######################
# FUNCTIONS
#######################
# clean_up
clean_up () {
  printf "Would you like to delete the tmp_dir and the downloaded files? (Yy/Nn) "
  read -r choice
  case "${choice}" in
    [yY]|[yY]es)
      printf '%s\n' "Cleaning up install files"
      cd && rm -rf "${tmp_dir}"
      exit "${1}"
      ;;
    *)
      printf '%s\n' "Exiting without deleting files from ${tmp_dir}"
      exit "${1}"
      ;;
  esac
}

# green output
code_grn () {
  tput setaf 2
  printf '%s\n' "${1}"
  tput sgr0
}

# red output
code_red () {
  tput setaf 1
  printf '%s\n' "${1}"
  tput sgr0
}

# yellow output
code_yel () {
  tput setaf 3
  printf '%s\n' "${1}"
  tput sgr0
}


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
    code_red "[ERROR] Unsupported OS. Exiting"
    exit 1
esac


#######################
# PATH CHECK
#######################
case :$PATH: in
  *:"${bin_dir}":*)  ;;  # do nothing
  *)
    code_red "[ERROR] ${bin_dir} was not found in \$PATH!"
    printf '%s\n' "Add ${bin_dir} to PATH or select another directory to install to"
    exit 1
    ;;
esac

if [ -d "${tmp_dir}" ]; then
  cd "${tmp_dir}" || exit
else
  code_red "[ERROR] ${tmp_dir} doesn't exist."
  exit 1
fi


#######################
# VERSION CHECK
#######################
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
  clean_up 0
else
  printf '%s\n' "Installed Verision: ${aws_installed_version}"
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
    code_red "[ERROR] AWS GPG Key not found"
    printf '%s\n' "Get it from here: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    clean_up 1
  else
    curl -s "${sigurl}" -o "${sigfile}"
  fi
fi


#######################
# PREPARE
#######################
if [ ! -d "${bin_dir}" ]; then
  printf '%s\n' "Creating ${bin_dir}"
  mkdir -p "${bin_dir}"
fi

if [ ! -d "${src_dir}" ]; then
  printf '%s\n' "Creating ${src_dir}"
  mkdir -p "${src_dir}"
fi

printf '%s\n' "Removing old version"
if [ -d "${aws_dir}" ]; then
  rm -f "${bin_dir}/aws"
  rm -f "${bin_dir}/aws_completer"
  rm -rf "${aws_dir}"
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

      printf '%s\n' "Creating symlinks"
      ln -s "${aws_dir}/aws" "${bin_dir}/aws"
      ln -s "${aws_dir}/aws_completer" "${bin_dir}/aws_completer"
      ;;
  "Linux")
      if gpg --verify "${sigfile}" "${installer}"; then
          unzip -q "${installer}"
          ./aws/install --bin-dir "${bin_dir}" --install-dir "${aws_dir}"
      else
          code_red "[ERROR] File failed GPG verification. Exiting."
          clean_up 1
      fi
      ;;
esac


#######################
# VERSION CHECK
#######################
code_grn "Old Version: ${aws_installed_version}"
code_grn "Installed Version: $(aws --version | cut -d' ' -f1 | cut -d'/' -f2)"


#######################
# CLEAN UP
#######################
clean_up 0

# vim: ft=sh ts=2 sts=2 sw=2 sr et
