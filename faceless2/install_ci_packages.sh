#!/usr/bin/env bash
# Reuse the runner image first; never refresh all apt mirrors just to reuse ffmpeg.
set -euo pipefail
ci_missing=()
for ci_package in "$@"; do
  if [[ "$(dpkg-query -W -f='${Status}' "$ci_package" 2>/dev/null || true)" != "install ok installed" ]]; then
    ci_missing+=("$ci_package")
  fi
done
if [[ ${#ci_missing[@]} == 0 ]]; then
  echo "CI_PACKAGES_REUSED $*"
  exit 0
fi
ci_apt=(sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 -o DPkg::Lock::Timeout=30)
if ! timeout --kill-after=15s 180s "${ci_apt[@]}" install -y -qq --no-install-recommends "${ci_missing[@]}"; then
  timeout --kill-after=15s 180s "${ci_apt[@]}" update -qq
  timeout --kill-after=15s 180s "${ci_apt[@]}" install -y -qq --no-install-recommends "${ci_missing[@]}"
fi
for ci_package in "${ci_missing[@]}"; do
  [[ "$(dpkg-query -W -f='${Status}' "$ci_package")" == "install ok installed" ]]
done
echo "CI_PACKAGES_INSTALLED ${ci_missing[*]}"
