# Troubleshooting

## "ninja: error: manifest 'build.ninja' still dirty after 100 tries"

Full text usually ends: *"perhaps system time is not set"*.

**Cause:** clock skew. Ninja decides what to rebuild by comparing file
modification times. If files have timestamps in the future relative to the
container's current clock, Ninja never reaches a stable state and gives up
after 100 retries. With Docker Desktop (macOS/Windows) the Linux VM clock
commonly drifts after the host sleeps or suspends.

**Fixes, in order:**

1. **Restart Docker Desktop** (fully quit and reopen — not just the container).
   This resyncs the VM clock and resolves the majority of cases.
   On Linux Docker Engine: `sudo systemctl restart docker`.

2. **Check the skew:**
   ```
   docker run --rm tenjin-windows date -u
   ```
   Compare to actual UTC. A large difference confirms the VM clock is wrong.

3. **Wipe the affected build directory** (it has bad timestamps baked in):
   ```
   ./tools/tool clean --target windows
   # or:  rm -rf build/windows-release
   ```
   Then re-run the build.

4. **If it persists**, the host clock itself may be wrong. Sync it:
   - macOS:  `sudo sntp -sS time.apple.com`
   - Linux:  `sudo timedatectl set-ntp true` then `sudo systemctl restart docker`
   - Windows: Settings ▸ Time & Language ▸ "Sync now".

**Project-side mitigation already in place:** the build mounts a persistent
named volume (`tenjin-deps-<image>`) at `/deps` and points
`FETCHCONTENT_BASE_DIR` there, so fetched dependencies (miniz) are built off
the bind-mounted workspace on a filesystem with consistent timestamps. This
removes the dependency-build step as a skew trigger and caches deps between
runs. It does not fix a skewed *host* clock affecting the app's own build dir —
for that, fixes 1–4 above are required.

To reset the dependency cache (e.g. to force a fresh miniz fetch):
```
docker volume rm tenjin-deps-tenjin-windows
```
