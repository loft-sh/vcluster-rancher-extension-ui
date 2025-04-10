# vCluster Rancher Extension UI Helm Chart

This Helm chart installs the vCluster Rancher Extension UI.

## Prerequisites

- Kubernetes 1.16+
- Rancher 2.10.0+
- Rancher UI Extensions 3.0.0+

## Installation

```bash
helm repo add vcluster https://charts.loft.sh
helm install vcluster-rancher-extension-ui vcluster/vcluster-rancher-extension-ui
```

## Configuration

See values.yaml for the available configuration options.

## Release Process

This chart is automatically published by CI when a new release is created in the GitHub repository. The chart version matches the git tag of the release.