#!/usr/bin/env bash

set -e

command -v yarn >/dev/null 2>&1 || {
  echo "yarn is required but not installed. Aborting." >&2
  exit 1
}

command -v yq >/dev/null 2>&1 || {
  echo "yq is required but not installed. Installing..." >&2
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install yq
  else
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.40.5/yq_linux_amd64 -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
  fi
}

# Parse arguments to detect dry-run
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
    break
  fi
done

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
  echo "Dependencies not found."
  
  # In dry-run mode, try to install dependencies
  if [ "$DRY_RUN" = true ]; then
    echo "Attempting to install dependencies for dry-run testing..."
    yarn install --frozen-lockfile || {
      echo "Failed to install dependencies. Continuing in dry-run mode with limited functionality."
    }
  else
    echo "Aborting. Run 'yarn install' first."
    exit 1
  fi
fi

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
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  *)
    echo "Unknown argument: $1"
    exit 1
    ;;
  esac
done

# helm plugin install https://github.com/chartmuseum/helm-push.git
# helm repo add chartmuseum $CHART_MUSEUM_URL --username $CHART_MUSEUM_USER --password $CHART_MUSEUM_PASSWORD

if [ -z "$BUMP_TYPE" ]; then
  echo "Usage:"
  echo "  $0 --bump <major|minor|patch> --user <username> --password <password>"
  echo "  $0 --bump <major|minor|patch> --dry-run"
  exit 1
fi

if [ "$DRY_RUN" = false ] && ([ -z "$USERNAME" ] || [ -z "$PASSWORD" ]); then
  echo "For actual publishing, username and password are required."
  echo "Usage: $0 --bump <major|minor|patch> --user <username> --password <password>"
  exit 1
fi

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN MODE - No changes will be pushed to remote repositories"
fi

# Bump the version based on argument
if [ "$DRY_RUN" = true ]; then
  echo "Bumping version ($BUMP_TYPE)"
  yarn run bump-$BUMP_TYPE || {
    echo "Warning: Version bump failed but continuing in dry-run mode"
    echo "    This might be due to missing dependencies"
    
    # For testing, simulate a version bump by using an existing version or creating a fake one
    if [ -f "./pkg/vcluster-rancher-extension-ui/package.json" ]; then
      echo "Using existing version from package.json"
    else
      echo "Creating a simulated version for testing"
      mkdir -p ./pkg/vcluster-rancher-extension-ui/
      echo '{"version": "0.0.999-test"}' > ./pkg/vcluster-rancher-extension-ui/package.json
    fi
  }
else
  yarn run bump-$BUMP_TYPE
fi

# Build the package locally
if [ ! -d "node_modules" ] && [ "$DRY_RUN" = true ]; then
  echo "Warning: Dependencies missing, cannot build package in dry-run mode"
  echo "For a full test, run 'yarn install' first"
  
  # Create directory structure to continue testing
  mkdir -p pkg/vcluster-rancher-extension-ui 2>/dev/null || true
else
  # Try different build approaches
  echo "Building package"
  BUILD_SUCCESS=false
  
  if [ -f "./node_modules/@rancher/shell/scripts/build-pkg.sh" ]; then
    # Use the shell script if available
    yarn build-pkg vcluster-rancher-extension-ui && BUILD_SUCCESS=true
  elif [ -d "pkg/vcluster-rancher-extension-ui" ]; then
    # Directly run build command in the package directory
    echo "Using direct build command"
    (cd pkg/vcluster-rancher-extension-ui && yarn build) && BUILD_SUCCESS=true
  else
    echo "No build method available"
  fi
  
  if [ "$BUILD_SUCCESS" = false ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "Warning: Build failed but continuing in dry-run mode"
    else
      echo "Error: Build failed"
      exit 1
    fi
  fi
fi

# Publish the package
if [ "$DRY_RUN" = false ]; then
  echo "Publishing package"
  yarn publish-pkgs -s loft-sh/vcluster-rancher-extension-ui
else
  echo "DRY RUN: Skipping package publishing"
fi 

# Get version from package.json
VERSION=$(node -p "require('./pkg/vcluster-rancher-extension-ui/package.json').version")
echo "Package version: $VERSION"

if [ "$DRY_RUN" = false ]; then
  helm plugin install https://github.com/chartmuseum/helm-push.git
  helm repo add chartmuseum https://charts.loft.sh --username $USERNAME --password $PASSWORD
fi

# Always update the chart files
echo "Updating chart version to $VERSION"
yq e -i ".version = \"${VERSION}\"" charts/vcluster-rancher-extension-ui/Chart.yaml
yq e -i ".appVersion = \"${VERSION}\"" charts/vcluster-rancher-extension-ui/Chart.yaml
yq e -i ".extension.version = \"${VERSION}\"" charts/vcluster-rancher-extension-ui/values.yaml

# Validate the chart first
echo "Validating chart"
if ! helm lint charts/vcluster-rancher-extension-ui/ &>/dev/null; then
  echo "Warning: Chart validation failed"
  if [ "$DRY_RUN" = false ]; then
    echo "Would you like to continue anyway? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
      echo "Aborting release due to chart validation failure"
      exit 1
    fi
    echo "Continuing despite validation issues"
  fi
fi

# Package the chart (but don't push)
echo "Packaging chart"
helm package charts/vcluster-rancher-extension-ui/ || {
  if [ "$DRY_RUN" = true ]; then
    echo "Warning: Helm packaging failed but continuing in dry-run mode"
    echo "    This might be due to missing internet connection or dependencies"
    # Create a dummy package for visualization
    echo "Creating placeholder package file for visualization"
    touch vcluster-rancher-extension-ui-${VERSION}.tgz
  else
    echo "Error: Helm packaging failed"
    exit 1
  fi
}

if [ "$DRY_RUN" = false ]; then
  # Save changes to git
  echo "Committing changes to git"
  git config user.name "loft-bot" || true
  git config user.email "github@loft.sh" || true
  git add charts/vcluster-rancher-extension-ui/
  git commit -m "chore(chart): update chart version to ${VERSION}"
  git push --force-with-lease origin HEAD:main

  # Push the chart
  echo "Pushing chart to repository"
  helm cm-push --force vcluster-rancher-extension-ui-${VERSION}.tgz chartmuseum
else
  echo "DRY RUN: Skipping git commit and push"
  echo "DRY RUN: Skipping helm chart push"
  echo "DRY RUN: Chart package created: vcluster-rancher-extension-ui-${VERSION}.tgz"
fi