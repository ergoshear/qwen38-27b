# syntax=docker/dockerfile:1
# Build llama.cpp for the GeForce RTX 4090 (Ada, compute capability 8.9).
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates cmake curl ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Pinned llama.cpp revision with Qwen3.5 architecture support used by Qwen3.8.
ARG LLAMA_CPP_REF=8345f333951c661d166b00e6f9362e553768f292
RUN mkdir -p /opt/llama.cpp \
    && curl -fL --retry 5 \
      "https://codeload.github.com/ggml-org/llama.cpp/tar.gz/${LLAMA_CPP_REF}" \
      | tar -xz --strip-components=1 -C /opt/llama.cpp

WORKDIR /opt/llama.cpp
ARG BUILD_JOBS=4
# The CUDA devel image includes the driver stub as libcuda.so. CUDA's SONAME is
# libcuda.so.1, which the linker needs to resolve when linking executables that
# depend on ggml-cuda. The stub is build-only; the NVIDIA container runtime
# supplies the real driver library at runtime.
RUN test -f /usr/local/cuda/targets/x86_64-linux/lib/stubs/libcuda.so \
    && ln -sfn libcuda.so /usr/local/cuda/targets/x86_64-linux/lib/stubs/libcuda.so.1
RUN cmake -S . -B build -G Ninja \
      -DGGML_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES=89 \
      -DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath-link,/usr/local/cuda/targets/x86_64-linux/lib/stubs \
      -DGGML_NATIVE=OFF \
      -DLLAMA_CURL=OFF \
      -DLLAMA_BUILD_TESTS=OFF \
      -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --parallel "$BUILD_JOBS"
RUN cmake --install build --prefix /opt/llama-install

FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/opt/llama/lib:/usr/local/cuda/lib64
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl jq libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/llama-install/ /opt/llama/
COPY entrypoint.sh /usr/local/bin/qwen38-entrypoint
COPY download-model.sh /usr/local/bin/download-model
RUN chmod 0755 /usr/local/bin/qwen38-entrypoint /usr/local/bin/download-model

VOLUME ["/models"]
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/qwen38-entrypoint"]
