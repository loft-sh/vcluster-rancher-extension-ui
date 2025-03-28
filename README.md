## Requirements

- Rancher version >= 2.10.0
- Rancher UI Extensions version >= 3.0.0 < 4.0.0
- Node.js >= 20

## Installation

1. Go to your main cluster repos page `/c/{CLUSTER_ID}/apps/catalog.cattle.io.clusterrepo`
2. Click on `Create`
3. Add a unique name, we recommend `loft`
4. Add the following URL to the repo: `https://charts.loft.sh`
5. Click on `Create`
6. Click on `Extensions` on the left sidebar
7. Under the `Available` tab, you should see `vCluster Rancher Extension UI`
8. Click on `Install`

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
