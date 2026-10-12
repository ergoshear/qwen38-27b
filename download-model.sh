#!/usr/bin/env bash
set -euo pipefail

repo=unsloth/Qwen3.8-27B-GGUF
file=Qwen3.8-27B-UD-Q4_K_M.gguf
default_revision=4ca720788d1e01f1bff70c033e0d0028fd02e502
mkdir -p /models
cd /models

fetch() {
    if [[ -n "${HF_TOKEN:-${HUGGINGFACE_API_KEY:-}}" ]]; then
        printf 'Authorization: %s %s\n' 'Bearer' "${HF_TOKEN:-$HUGGINGFACE_API_KEY}" |
            curl -fL --retry 5 --retry-all-errors --header @- "$@"
    else
        curl -fL --retry 5 --retry-all-errors "$@"
    fi
}

if [[ -s model-revision.txt ]]; then
    revision=$(cat model-revision.txt)
    if [[ -n "${MODEL_REVISION:-}" && "$MODEL_REVISION" != "$revision" ]]; then
        printf 'Use a new volume to change the saved model revision.\n' >&2
        exit 1
    fi
else
    revision=${MODEL_REVISION:-$default_revision}
fi
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    printf 'Expected a full Hugging Face commit SHA, got: %s\n' "$revision" >&2
    exit 1
fi
fetch "https://huggingface.co/api/models/$repo/revision/$revision?blobs=true" \
    --output model-metadata.json.partial
checksum=$(jq -er --arg file "$file" \
    '.siblings[] | select(.rfilename == $file) | .lfs.sha256' model-metadata.json.partial)
if [[ ! "$checksum" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'Model metadata is missing a valid LFS SHA256.\n' >&2
    exit 1
fi
mv model-metadata.json.partial model-metadata.json
printf '%s\n' "$revision" > model-revision.txt.partial
mv model-revision.txt.partial model-revision.txt

if [[ -f "$file" ]]; then
    printf '%s  %s\n' "$checksum" "$file" | sha256sum --check -
    exit 0
fi
fetch "https://huggingface.co/$repo/resolve/$revision/$file" \
    --continue-at - --output "$file.partial"
printf '%s  %s\n' "$checksum" "$file.partial" | sha256sum --check -
mv "$file.partial" "$file"
printf 'Downloaded %s at revision %s\n' "$file" "$revision"
