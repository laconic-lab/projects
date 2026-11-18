# 05 — DKMS and driver reference

## Observed DKMS status
```text
nvidia/470.256.02, 6.8.0-147-generic, x86_64: installed
nvidia/580.178.04, 6.8.0-139-generic, x86_64: installed
nvidia/580.178.04, 6.8.0-147-generic, x86_64: built
virtualbox/7.0.16, 6.8.0-147-generic, x86_64: installed
```

`installed` means DKMS has installed that module for the named kernel. `built` means DKMS has built it but does not report it as installed for that kernel. Neither status alone identifies the currently loaded driver.

## Active driver checks
```bash
uname -r
cat /proc/driver/nvidia/version
modinfo -F version nvidia
modinfo -n nvidia
nvidia-smi
```

Interpret `nvidia-smi` alongside the loaded module and library links.

## Important warning
Runfile and APT DKMS configurations both use `nvidia/470.256.02`. Do not casually run:
```bash
sudo dkms remove -m nvidia -v 470.256.02 --all
```
That can remove registrations across kernels.

## Desired future status
After a separately approved and verified correction, the intended 470 DKMS entry should remain installed for the target kernel, with unrelated modules such as VirtualBox preserved. 580 entries should be absent only if the package correction safely removes those registrations. This target has not yet been achieved.
