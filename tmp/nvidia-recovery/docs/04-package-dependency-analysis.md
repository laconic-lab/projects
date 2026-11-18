# 04 — APT dependency analysis

## Installed transitional dependencies observed
```text
nvidia-dkms-470-server -> nvidia-dkms-535 -> nvidia-dkms-580
nvidia-driver-470-server -> nvidia-driver-535 -> nvidia-driver-580
```

Observed versions:
- 470-server: `470.256.02-0ubuntu0.24.04.5`
- 535: `535.309.01-0ubuntu0.24.04.2`
- 580: `580.178.04-0ubuntu0.24.04.1`

The 470-server driver and DKMS packages were held. The server kernel-common package was held but not installed. APT autoremove proposed no removals because the packages remained required through dependencies.

## Critical runfile/APT overlap
The regular APT `nvidia-dkms-470` package uses the same DKMS identity as the runfile installation: `nvidia/470.256.02`. The inspected package `preinst` invokes `/usr/bin/nvidia-uninstall -s` when present. Its postinst/prerm operate on the same DKMS identity. Its packaged `dkms.conf` differs from the runfile configuration. Installing/removing it without a designed transition is unsafe.

## Generic symlink ownership conflict
`libnvidia-compute-580:amd64` owns generic paths including:
- `/usr/lib/x86_64-linux-gnu/libcuda.so`
- `/usr/lib/x86_64-linux-gnu/libcuda.so.1`
- `/usr/lib/x86_64-linux-gnu/libnvidia-ml.so`
- `/usr/lib/x86_64-linux-gnu/libnvidia-ml.so.1`

At inspection, these links resolved to 470 versioned libraries not owned by dpkg. Removing the 580 package may remove these links. A future plan must account for this explicitly.

580 package ownership was also found for `libcudadebugger.so.580.178.04` and `libnvidia-nvvm70.so.4`. `libnvidia-nvvm.so.4.0.0` was not dpkg-owned but was recorded in the NVIDIA installer database.

## Prior simulation
A simulation of regular 470 packages plus removal of 470-server packages proposed 32 new packages and 24 removals. It was not executed. Because of the runfile/DKMS overlap, it must not be treated as approved or safe.

## Required future procedure
1. Refresh metadata and re-audit current system.
2. Reconfirm GPU, active driver, kernel, packages, holds and DKMS.
3. Inspect current candidate metadata and maintainer scripts.
4. Inspect all relevant symlink targets and package ownership.
5. Create and verify fresh backup.
6. Simulate exact transaction.
7. Review every install/removal/hold change.
8. Obtain explicit approval of that exact transaction.
9. Execute only the approved transaction.
10. Verify driver, libraries, DKMS, display and reboot.
