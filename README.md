## Requirements

- Rancher version >= 2.10.0
- Rancher UI Extensions version >= 3.0.0 < 4.0.0
- Node.js >= 20

## Installation

1. In the Rancher UI, click on the Extensions in the left side menu. Click on the ellipsis menu on the top right and select Manage Repositories.
2. Click on Create on the right. Give the repository a name and enter https://charts.loft.sh/ as the Index URL.
3. Click on Create at the bottom.
4. Navigate back to the Extensions page and click on Available tab. Click Install on the extension named `vCluster Rancher Extension UI`.

## Using the extension

1. There are multiple ways to create a vCluster from the Rancher UI :
   - Rancher homepage -> Create vCluster
   - Rancher Cluster management page --> Create cluster
   - vCluster List page left side menu --> Create vCluster
2. From the dropdown menu, choose the host cluster where you'd like to deploy your virtual cluster.
3. If the charts.loft.sh repository isn't already configured on your selected cluster, you'll be given the option to add it automatically or manually.
   - If you choose to add it manually, click on Create on the right. Give the repository a name and enter https://charts.loft.sh/ as the Index URL.
4. Select your preferred vCluster version from the available options.
5. Specify a namespace and name for your virtual cluster, then click `Create vCluster` to begin the deployment.
6. Select vCluster List page left side menu to view the created vCluster
7. The vCluster should show up as a regular downstream cluster in Rancher and be available in the left side menu
8. Click on the vCluster to navigate to Cluster explorer page to use the cluster.

## Development

### Prerequisites

- Node.js >= 20
- npm or yarn package manager

### Setup

```bash
yarn install

API={RANCHER_API_URL} yarn dev
```

## Release process

### Automated release (CI)

The extension is automatically built and published when a new GitHub release is created with a tag (e.g., `v0.1.0`). The CI workflow:

1. Builds the extension package
2. Updates the Helm chart version to match the release
3. Commits the chart changes back to the repository
4. Publishes the extension and chart to the Loft charts repository
5. Sends a notification about the release

### Manual release

For manual releases, you need credentials for the chart repository:

```bash
# Install dependencies first
yarn install

# Release with version bump
hack/publish-pkg.sh --bump <major|minor|patch> --user <username> --password <password>
```

### Testing the release process

You can test the release process without publishing anything:

```bash
# Dry run mode (builds locally but doesn't push anything)
hack/publish-pkg.sh --bump <major|minor|patch> --dry-run
```

## Helm chart

The extension is packaged as a Helm chart and published to the Loft charts repository. The chart:

- Installs the vCluster Rancher Extension UI
- Configures extension metadata for Rancher
- Includes compatibility requirements

The chart is maintained in the `charts/vcluster-rancher-extension-ui` directory in this repository.

To use the chart directly:

```bash
helm repo add loft https://charts.loft.sh
helm repo update
helm install vcluster-rancher-extension-ui loft/vcluster-rancher-extension-ui
```
