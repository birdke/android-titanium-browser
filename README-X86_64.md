# Titanium Browser x86_64 test build

This branch builds Chromium/Titanium `v152.0.7977.54` as a native Android
`x86_64` APK for Bliss OS and other Android-x86 systems.

The package id is `io.github.jqssun.helium.x64`, so the test build can be
installed next to the official ARM package without replacing its data.

The `Build Titanium x86_64` workflow is manual-only. It reclaims unused tools
from the ephemeral Ubuntu runner, combines the root and `/mnt` free space into
an LVM workspace, builds only `chrome_public_apk`, signs it with repository
secrets, and retains the resulting artifact for one day.

The hosted-runner profile defaults to four compile jobs, provides 24 GiB of
swap, protects the Actions runner processes from the OOM killer, and runs the
compiler at a lower CPU priority so the runner can keep reporting status under
heavy load.

Required Actions secrets:

- `LOCAL_TEST_JKS`: base64-encoded `local.properties`
- `STORE_TEST_JKS`: base64-encoded Java keystore

The expanded-disk method relies on the current GitHub-hosted runner layout and
therefore checks for at least 108 GiB of available workspace before checkout.
