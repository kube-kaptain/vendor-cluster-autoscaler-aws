# Vendor Cluster Autoscaler AWS

Vendored Kubernetes Cluster Autoscaler helm chart rendered to plain kubernetes
manifests using the `kubernetes-bundle-vendor-helm-rendered` build type.

The helm chart is fetched from `https://kubernetes.github.io/autoscaler`
at build time, rendered via `helm template`, and processed through the standard
pipeline (split, map, transform, label, validate). The output is committed tokenised
plain manifests in `src/kubernetes/` with no helm runtime dependency.

This package configures the Cluster Autoscaler for **AWS** using ASG
auto-discovery (`--node-group-auto-discovery` by cluster tag).


## Upstream

- Project: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler
- Chart repo: `https://kubernetes.github.io/autoscaler`
- Chart name: `cluster-autoscaler`
- Version tracked in: `src/config/VendorHelmRenderedVersion`


## Versioning

Unlike most charts, the cluster-autoscaler chart version (9.x) is decoupled from
the application version (1.x). The application minor tracks the Kubernetes minor
it autoscales, so the image tag in `KaptainPM.yaml` must be chosen to match the
target cluster version.

Our release versions follow the **application** version, not the chart version.
The application version is extracted from the image tag in `KaptainPM.yaml`'s
`imageRetags` section (e.g. `v1.32.7`) and our packaging version appends an
increment: `1.32.7.1`, `1.32.7.2`, etc.

The upstream chart version (e.g. `9.46.6`) is stored in
`src/config/VendorHelmRenderedVersion` and drives which chart is fetched and
rendered. The version pairing validation hook asserts the pinned pieces agree:
a values file exists for the pinned chart version, and the pulled chart's
`appVersion` matches the image tag at major.minor, while allowing the image to
run a newer patch than the chart's `appVersion` pins.

Latest chart version per application (= Kubernetes) minor:

| App / Kubernetes minor | Latest chart version |
|------------------------|----------------------|
| 1.32                   | 9.46.6               |
| 1.33                   | 9.51.0               |
| 1.34                   | 9.53.0               |
| 1.35                   | 9.58.0               |
| 1.36                   | not yet released     |

The currently deployed pairing is whatever `src/config/VendorAppVersion`,
`src/config/VendorHelmRenderedVersion` and the image tag in `KaptainPM.yaml` say.


## Structure

- `src/config/VendorHelmRenderedVersion`          - upstream chart version (drives chart fetch)
- `src/vendor-helm-rendered/values-*.yaml`        - version-specific helm values overrides
- `src/kubernetes/`                               - final committed output (plain manifests)
- `.github/bin/validate-version-pairing.bash`     - asserts image tag and chart appVersion agree
