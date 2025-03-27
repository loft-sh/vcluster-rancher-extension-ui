#!/usr/bin/env bash

set -e

command -v yarn >/dev/null 2>&1 || { echo "yarn is required but not installed. Aborting." >&2; exit 1; }
# Source nvm if it exists in common locations
if [ -f "$HOME/.nvm/nvm.sh" ]; then
    . "$HOME/.nvm/nvm.sh"  # This loads nvm
elif [ -f "/usr/local/opt/nvm/nvm.sh" ]; then
    . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
else
    echo "Cannot find nvm installation. Please make sure nvm is installed." >&2
    exit 1
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

nvm use 20

# Build the package
yarn build-pkg vcluster-rancher-extension-ui

# Publish the package
yarn publish-pkgs vcluster-rancher-extension-ui

# Get version from package.json
VERSION=$(node -p "require('./pkg/vcluster-rancher-extension-ui/package.json').version")
echo "Package version: $VERSION"


