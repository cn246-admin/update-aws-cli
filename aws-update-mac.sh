#!/usr/bin/env bash

username=$(whoami)
link_one="/Users/${username}/.local/bin/aws"
link_two="/Users/${username}/.local/bin/aws_completer"

if [ ! -f choices.xml ]; then
  cat << EOF > choices.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <array>
    <dict>
      <key>choiceAttribute</key>
      <string>customLocation</string>
      <key>attributeSetting</key>
      <string>/Users/${username}/.local/</string>
      <key>choiceIdentifier</key>
      <string>default</string>
    </dict>
  </array>
</plist>
EOF
fi

# Download latest aws-cli
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

printf '%s\n' "Installing aws-cli"
installer -pkg AWSCLIV2.pkg \
  -target CurrentUserHomeDirectory \
  -applyChoiceChangesXML choices.xml

if [ ! -e "${link_one}" ]; then
  printf '%s\n' "Creating ${link_one}"
  rm -f "${link_one}"
  ln -fs "/Users/${username}/.local/aws-cli/aws" "${link_one}"
fi

if [ ! -e "${link_two}" ]; then
  printf '%s\n' "Creating ${link_two}"
  rm -f "${link_two}"
  ln -fs "/Users/${username}/.local/aws-cli/aws_completer" "${link_two}"
fi

printf '%s\n' "aws-cli will be run from:"
command -v aws

printf '%s\n' "aws-cli version:"
aws --version

printf '%s\n' "Cleaning up"
rm -f "AWSCLIV2.pkg"

# vim: ft=sh ts=2 sts=2 sw=2 sr et