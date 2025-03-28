#!/usr/bin/env bash

set -e

command -v yarn >/dev/null 2>&1 || {
  echo "yarn is required but not installed. Aborting." >&2
  exit 1
}

# Function to check if node version meets requirements
check_node_version() {
  required_version="v20"
  if which node >/dev/null; then
    current_version=$(node -v)
    if [[ "$current_version" != "$required_version"* ]]; then
      echo "node version 20 is required." >&2
      exit 1
    fi
  else
    echo "node version 20 is required." >&2
    exit 1
  fi
}

# Try to source nvm if it exists
if [ -f "$HOME/.nvm/nvm.sh" ]; then
  . "$HOME/.nvm/nvm.sh"
  nvm use 20 || {
    echo "Failed to switch to node version 20 using nvm. Checking system node version..." >&2
    check_node_version
  }
elif [ -f "/usr/local/opt/nvm/nvm.sh" ]; then
  . "/usr/local/opt/nvm/nvm.sh"
  nvm use 20 || {
    echo "Failed to switch to node version 20 using nvm. Checking system node version..." >&2
    check_node_version
  }
else
  echo "nvm not found. Checking system node version..." >&2
  check_node_version
fi

if ! helm plugin list | grep -q "push"; then
  echo "Error: helm push plugin not found. Please install it with:"
  echo "helm plugin install https://github.com/chartmuseum/helm-push.git"
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
  --bump)
    BUMP_TYPE="$2"
    shift 2
    ;;
  --user)
    USERNAME="$2"
    shift 2
    ;;
  --password)
    PASSWORD="$2"
    shift 2
    ;;
  *)
    echo "Unknown argument: $1"
    exit 1
    ;;
  esac
done

# helm plugin install https://github.com/chartmuseum/helm-push.git
# helm repo add chartmuseum $CHART_MUSEUM_URL --username $CHART_MUSEUM_USER --password $CHART_MUSEUM_PASSWORD

if [ -z "$BUMP_TYPE" ] || [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 --bump <major|minor|patch> --user <username> --password <password>"
  exit 1
fi

# Bump the version based on argument
yarn run bump-$BUMP_TYPE

# Build the package
yarn build-pkg vcluster-rancher-extension-ui

# Publish the package
yarn publish-pkgs vcluster-rancher-extension-ui

# Get version from package.json
VERSION=$(node -p "require('./pkg/vcluster-rancher-extension-ui/package.json').version")
echo "Package version: $VERSION"
