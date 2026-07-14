#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# pre-package-prepare hook for vendor-cluster-autoscaler-aws
#
# The cluster-autoscaler chart version (9.x) is decoupled from the application
# version (1.x) which tracks the Kubernetes minor it autoscales. Our release
# versioning is derived from the image tag in KaptainPM.yaml, so this hook
# asserts that the pinned pieces agree:
#
#   1. src/vendor-helm-rendered/values-<chartVersion>.yaml exists for the
#      chart version pinned in src/config/VendorHelmRenderedVersion
#   2. The pulled chart's appVersion (read from the build's A-chart stage)
#      has the same major.minor as the image tag in KaptainPM.yaml's
#      imageRetags
#   3. The image tag patch is >= the chart appVersion patch (the image may
#      run a newer patch than the chart pins, never an older one)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CHART_VERSION_FILE="${REPO_ROOT}/src/config/VendorHelmRenderedVersion"
KAPTAIN_PM_FILE="${REPO_ROOT}/KaptainPM.yaml"

CHART_VERSION="$(head -n 1 "${CHART_VERSION_FILE}" | tr -d '[:space:]')"

CHART_NAME="$(grep -E "^[[:space:]]*chartName:" "${KAPTAIN_PM_FILE}" | head -1 | sed -E "s/^[[:space:]]*chartName:[[:space:]]*'?([^']*)'?$/\\1/")"

IMAGE_URI="$(grep -E "^[[:space:]]*- sourceImageUri:" "${KAPTAIN_PM_FILE}" | head -1 | sed -E "s/^[[:space:]]*- sourceImageUri:[[:space:]]*'?([^']*)'?$/\\1/")"
IMAGE_TAG="${IMAGE_URI##*:}"
IMAGE_VERSION="${IMAGE_TAG#v}"

VALUES_FILE="${REPO_ROOT}/src/vendor-helm-rendered/values-${CHART_VERSION}.yaml"
if [ ! -f "${VALUES_FILE}" ]; then
  printf 'ERROR: no values file for chart version %s: %s\n' "${CHART_VERSION}" "${VALUES_FILE}" >&2
  printf 'Create src/vendor-helm-rendered/values-%s.yaml or fix src/config/VendorHelmRenderedVersion.\n' "${CHART_VERSION}" >&2
  exit 1
fi
printf 'OK: values file present for chart version %s\n' "${CHART_VERSION}"

PULLED_CHART_FILE="${OUTPUT_SUB_PATH}/helm-processing/A-chart/${CHART_NAME}/Chart.yaml"
if [ ! -f "${PULLED_CHART_FILE}" ]; then
  printf 'ERROR: pulled chart not found: %s\n' "${PULLED_CHART_FILE}" >&2
  exit 1
fi

CHART_APP_VERSION="$(grep -E '^appVersion:' "${PULLED_CHART_FILE}" | head -1 | sed -E 's/^appVersion:[[:space:]]*"?v?([0-9.]+)"?$/\1/')"
if [ -z "${CHART_APP_VERSION}" ]; then
  printf 'ERROR: could not read appVersion from %s\n' "${PULLED_CHART_FILE}" >&2
  exit 1
fi
printf 'Chart %s %s has appVersion %s, image tag is %s\n' "${CHART_NAME}" "${CHART_VERSION}" "${CHART_APP_VERSION}" "${IMAGE_TAG}"

CHART_APP_MAJOR_MINOR="$(printf '%s' "${CHART_APP_VERSION}" | awk -F. '{print $1 "." $2}')"
IMAGE_MAJOR_MINOR="$(printf '%s' "${IMAGE_VERSION}" | awk -F. '{print $1 "." $2}')"

if [ "${CHART_APP_MAJOR_MINOR}" != "${IMAGE_MAJOR_MINOR}" ]; then
  printf 'ERROR: chart appVersion %s (%s) does not match image tag %s (%s) at major.minor\n' "${CHART_APP_VERSION}" "${CHART_APP_MAJOR_MINOR}" "${IMAGE_TAG}" "${IMAGE_MAJOR_MINOR}" >&2
  printf 'Bump src/config/VendorHelmRenderedVersion or the KaptainPM.yaml imageRetags tag so they agree.\n' >&2
  exit 1
fi
printf 'OK: chart appVersion and image tag agree at major.minor %s\n' "${IMAGE_MAJOR_MINOR}"

CHART_APP_PATCH="$(printf '%s' "${CHART_APP_VERSION}" | awk -F. '{print $3 + 0}')"
IMAGE_PATCH="$(printf '%s' "${IMAGE_VERSION}" | awk -F. '{print $3 + 0}')"

if [ "${IMAGE_PATCH}" -lt "${CHART_APP_PATCH}" ]; then
  printf 'ERROR: image tag %s is an older patch than chart appVersion %s\n' "${IMAGE_TAG}" "${CHART_APP_VERSION}" >&2
  printf 'The image may run a newer patch than the chart pins, never an older one.\n' >&2
  exit 1
fi
printf 'OK: image patch %s >= chart appVersion patch %s\n' "${IMAGE_PATCH}" "${CHART_APP_PATCH}"
