# 02 — Before and current state diagrams

These are reconstructed states from the 2026-11-01 investigation. No package corrections were performed.

## A. Transitional package chain discovered

```text
470-server driver package
          |
          v
     535 driver package
          |
          v
     580 driver package

470-server DKMS package
          |
          v
     535 DKMS package
          |
          v
     580 DKMS package
```

The working 470.256.02 runfile driver remained loaded while APT's transitional packages and 580 DKMS entries remained installed/built.

## B. Current observed runtime/library state

```text
Kernel 6.8.0-147-generic
          |
          v
Loaded NVIDIA 470.256.02
          |
          +--> CUDA -> libcuda.so.470.256.02
          +--> NVML -> libnvidia-ml.so.470.256.02
          +--> OpenCL -> libnvidia-opencl.so.470.256.02
          +--> PTX JIT -> libnvidia-ptxjitcompiler.so.470.256.02
          |
          +--> NVVM -> libnvidia-nvvm.so.4.0.0
          |             recorded in installer database;
          |             not dpkg-owned
          |
          +--> Residual 580 files include:
                libcudadebugger.so.580.178.04
                libnvidia-nvvm70.so.4
```

## C. Desired target — not yet achieved

```text
NVIDIA 470.256.02 active and verified
          |
          +--> intended 470 DKMS installed for target kernel
          +--> coherent 470 userspace/library links
          +--> no 535/580 transitional package chain
          +--> no obsolete 580 DKMS registrations
```

Exact final package set must be determined from a fresh audit and reviewed APT simulation. Do not assume every 580-named file can simply be deleted.
