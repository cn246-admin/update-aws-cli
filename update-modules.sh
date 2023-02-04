#!/bin/sh

script_path="$HOME/Projects/aws/0"
requirements_txt="${script_path}/requirements.txt"
venv_path="${script_path}/venv"

upgrade_modules () {
  python3 -m pip install --upgrade -r "${requirements_txt}"
}

# Check venv exists
if [ ! -f "${venv_path}/bin/activate" ]; then
  printf '%s\n' "Could not find ${venv_path}/bin/activate. Exiting"
  exit 1
fi

# Check for requirements.txt file
if [ ! -f "${requirements_txt}" ]; then
  cat << EOF > "${requirements_txt}"
boto3>=1.24.80
cfn-lint>=0.65.1
pip>=22.3.1
yamllint>=1.28.0
EOF
fi

# Check if venv is active and upgrade modules
if [ "$VIRTUAL_ENV" = "$venv_path" ]; then
  upgrade_modules
else
  source "${venv_path}/bin/activate"
  upgrade_modules
fi

# vim: ft=sh ts=2 sts=2 sw=2 sr et