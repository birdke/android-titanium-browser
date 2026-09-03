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
the ephemeral Ubuntu runner, combines the root and `/mnt` free space into an
LVM workspace, builds only `chrome_public_apk`, signs it with repository
secrets, retains the Actions artifact for one day, and publishes the APK and
SHA256 checksum to a `v<upstream-version>-x86_64` GitHub Release.

The hosted-runner profile defaults to four compile jobs, provides 24 GiB of
swap, protects the Actions runner processes from the OOM killer, and runs the
compiler at a lower CPU priority so the runner can keep reporting status under
heavy load.

Required Actions secrets:

- `LOCAL_TEST_JKS`: base64-encoded `local.properties`
- `STORE_TEST_JKS`: base64-encoded Java keystore

Scheduled workflows run from the repository's default branch, which must
remain `x86_64-actions` unless the sync workflow configuration is updated.

The expanded-disk method relies on the current GitHub-hosted runner layout and
therefore checks for at least 108 GiB of available workspace before checkout.
