# Titanium Browser x86_64 test build

This branch builds the latest published upstream Chromium/Titanium release as
a native Android `x86_64` APK for Bliss OS and other Android-x86 systems.

The package id is `io.github.jqssun.helium.x64`, so the test build can be
installed next to the official ARM package without replacing its data.

The `Follow upstream Titanium releases` workflow checks the latest published
upstream release every six hours. When a new tag appears, it merges that tag
into `x86_64-actions` and dispatches the `Build Titanium x86_64` workflow. A
merge conflict stops the update without changing the branch. Active builds and
existing x86_64 releases are detected so duplicate builds are not started.

The build workflow can also be started manually. It reclaims unused tools from
the ephemeral Ubuntu 24.04 runner, builds only `chrome_public_apk`, signs it
with repository secrets, retains the APK artifact for one day, and publishes
the APK and SHA256 checksum to a `v<upstream-version>-x86_64` GitHub Release.

Disk preparation checks the filesystem device IDs of `/var/tmp` and `/mnt`.
When they share a filesystem, the build uses the native workspace and 8 GiB
of swap instead of counting the same free space twice. With separate
filesystems, it combines fully allocated backing files into an LVM workspace
and provides 24 GiB of swap. Formatting disables discard to preserve the
backing allocation.

The hosted-runner profile defaults to four compile jobs, protects the Actions
runner processes from the OOM killer, and runs the compiler at a lower CPU
priority so the runner can keep reporting status under heavy load.

Every minute, the build logs memory, swap, underlying and workspace filesystem
capacity and inode usage, CPU/memory/I/O pressure, top processes, and recent
kernel messages. It also attempts a final snapshot and uploads diagnostics
with 14-day retention even after a failed build. A lost or forcibly terminated
runner cannot guarantee final collection or artifact upload; the periodic
Actions log remains the fallback evidence.

Required Actions secrets:

- `LOCAL_TEST_JKS`: base64-encoded `local.properties`
- `STORE_TEST_JKS`: base64-encoded Java keystore

Scheduled workflows run from the repository's default branch, which must
remain `x86_64-actions` unless the sync workflow configuration is updated.

After allocating swap, preparation requires at least 108 GiB of available
workspace. On a shared root filesystem it additionally requires an 8 GiB
margin; with LVM that margin is reserved outside the root backing file (plus
1 GiB on the separate `/mnt` filesystem). These are setup-time checks, not
runtime quotas.
