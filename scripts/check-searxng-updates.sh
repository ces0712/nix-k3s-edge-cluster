#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(dirname -- "$SCRIPT_DIR")"
readonly OPTIONS_FILE="$REPO_ROOT/modules/options.nix"
readonly TAGS_URL='https://hub.docker.com/v2/repositories/searxng/searxng/tags?page_size=100&ordering=last_updated'

for command in curl jq sed; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

current_ref="$(
  sed -n 's|^[[:space:]]*default = "\(docker\.io/searxng/searxng:[^"]*@sha256:[[:xdigit:]]\{64\}\)";$|\1|p' "$OPTIONS_FILE"
)"

if [[ -z "$current_ref" || "$current_ref" == *$'\n'* ]]; then
  printf 'error: expected one digest-pinned SearXNG image in %s\n' "$OPTIONS_FILE" >&2
  exit 1
fi

current_tag="${current_ref#docker.io/searxng/searxng:}"
current_tag="${current_tag%@*}"
current_digest="${current_ref##*@}"

tags_json="$(curl --fail --silent --show-error --location "$TAGS_URL")"
latest_json="$(
  printf '%s' "$tags_json" | jq -cer '
    [
      .results[]
      | select(.name | test("^[0-9]{4}\\.[0-9]+\\.[0-9]+-[0-9a-f]+$"))
      | . + {
          version_parts: (
            .name
            | capture("^(?<year>[0-9]{4})\\.(?<month>[0-9]+)\\.(?<day>[0-9]+)-")
            | [.year, .month, .day]
            | map(tonumber)
          )
        }
    ]
    | sort_by(.version_parts + [.last_updated])
    | last
    // error("no versioned SearXNG tag found")
  '
)"

latest_tag="$(printf '%s' "$latest_json" | jq -er '.name')"
latest_digest="$(printf '%s' "$latest_json" | jq -er '.digest')"
arm64_digest="$(
  printf '%s' "$latest_json" | jq -er '
    first(.images[]? | select(.os == "linux" and .architecture == "arm64") | .digest)
    // error("latest versioned tag has no linux/arm64 child manifest")
  '
)"

if [[ ! "$latest_digest" =~ ^sha256:[0-9a-f]{64}$ || ! "$arm64_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  printf 'error: Docker Hub returned an invalid manifest digest\n' >&2
  exit 1
fi

printf 'Current tag:          %s\n' "$current_tag"
printf 'Current index digest: %s\n' "$current_digest"
printf 'Latest tag:           %s\n' "$latest_tag"
printf 'Latest index digest:  %s\n' "$latest_digest"
printf 'Linux/arm64 child:    %s\n' "$arm64_digest"

if [[ "$current_tag" != "$latest_tag" || "$current_digest" != "$latest_digest" ]]; then
  printf 'Update available.\n'
  exit 2
fi

printf 'SearXNG image is current.\n'
