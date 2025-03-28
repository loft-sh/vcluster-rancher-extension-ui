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

You need a username and password to chartmuseum to push the new version.

```bash
hack/publish-pkg.sh --bump <major|minor|patch> --user <username> --password <password>
```
