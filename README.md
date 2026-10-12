# Qwen3.8-27B Q4_K_M

This directory builds a CUDA `llama.cpp` server image for the GeForce RTX 4090
(Ada, compute capability 8.9).

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
- The 24 GiB GPU cannot safely hold the model, a 262K cache, and all runtime
  buffers at once. By default 56 layers are offloaded to the GPU and the
  remaining layers use host RAM. Lower `GPU_LAYERS` first if startup runs out of
  memory. Actual allocation depends on the llama.cpp revision and other GPU
  processes.

## Build and download

Use Linux with a working NVIDIA driver and NVIDIA Container Toolkit. The image
provides CUDA user space and targets Ada architecture 8.9.

```sh
podman build --format docker -t qwen38-27b-4090 .
podman volume create qwen38-27b-model
podman run --rm --gpus all -v qwen38-27b-model:/models \
  --entrypoint /usr/local/bin/download-model qwen38-27b-4090
```

The model is public. If Hugging Face requires authentication, pass `HF_TOKEN`
only to the download command. Keep at least 20 GB free for the model volume.

## Run the server

```sh
podman run -d --name qwen38-27b \
  --gpus all --shm-size 8g \
  -v qwen38-27b-model:/models:ro \
  -p 127.0.0.1:8080:8080 \
  qwen38-27b-4090
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
