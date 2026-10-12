# Qwen3.8-27B Q4_K_M

This directory builds a ROCm/HIP `llama.cpp` server image for
`mlops-node-4.lan`: AMD Radeon AI PRO R9700 (`gfx1201`) with 32 GiB VRAM and
64 GiB system RAM.

## Model

- GGUF: [`unsloth/Qwen3.8-27B-GGUF`](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF),
  `Qwen3.8-27B-UD-Q4_K_M.gguf` (16.5 GB), Unsloth's current dynamic Q4_K_M
  quantization.
- The downloader pins revision
  `4ca720788d1e01f1bff70c033e0d0028fd02e502` by default and verifies the
  downloaded file against its Hugging Face LFS SHA256. Set `MODEL_REVISION` to
  override the revision; a saved model volume keeps its original revision.
- Native context is 262,144 tokens. The server defaults to 65,536 tokens, one
  parallel slot, and Q4_0 K/V cache. Runtime settings can be changed with
  `GPU_LAYERS`, `CTX_SIZE`, `PARALLEL`, `THREADS`, `BATCH_SIZE`, `UBATCH_SIZE`,
  `CACHE_TYPE_K`, `CACHE_TYPE_V`, `FLASH_ATTN`, `TEMP`, `TOP_P`, and `TOP_K`.
- The server defaults to offloading up to 99 layers to the GPU. Its 65,536-token
  context and Q4_0 K/V cache are sized for the 32 GiB card; lower `GPU_LAYERS`
  or `CTX_SIZE` if startup runs out of memory. Actual allocation depends on the
  llama.cpp revision and other GPU processes.

## Build and download

Use Linux with a working AMDGPU driver and ROCm access to `/dev/kfd` and
`/dev/dri`. The container supplies ROCm 7.2.3 user space and targets `gfx1201`.

```sh
podman build --format docker -t qwen38-27b .
podman volume create qwen38-27b-model
podman run --rm -v qwen38-27b-model:/models \
  --entrypoint /usr/local/bin/download-model qwen38-27b
```

The model is public. If Hugging Face requires authentication, pass `HF_TOKEN`
only to the download command. Keep at least 20 GB free for the model volume.

## Run the server

```sh
podman run -d --name qwen38-27b \
  --device /dev/kfd --device /dev/dri --group-add keep-groups \
  -v qwen38-27b-model:/models:ro \
  -p 127.0.0.1:8080:8080 \
  qwen38-27b
podman logs -f qwen38-27b
```

Check readiness and send a small request after the model has loaded:

```sh
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen3.8-27B","messages":[{"role":"user","content":"Write a Python function that returns the first n Fibonacci numbers."}],"max_tokens":128,"temperature":0}'
```

The image has not been built or run on the target host as part of this change.
Confirm its startup log reports the requested context and test an inference
request on that host before relying on the service.
