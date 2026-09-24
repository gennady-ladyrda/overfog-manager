# Release and installation

Releases are created by pushing a version tag matching `v*`, for example:

```sh
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions runs the repository tests, checks POSIX shell syntax, builds the
self-extracting installer, calculates its SHA-256 file, and publishes both
files to the GitHub Release.

The release contains:

```text
overfog-manager-installer.run
overfog-manager-installer.run.sha256
```

## Online installation on the router

Replace `<OWNER>/<REPOSITORY>` and `<VERSION>` with the actual GitHub release
coordinates:

```sh
cd /tmp
curl -fL \
  "https://github.com/<OWNER>/<REPOSITORY>/releases/download/<VERSION>/overfog-manager-installer.run" \
  -o overfog-manager-installer.run
curl -fL \
  "https://github.com/<OWNER>/<REPOSITORY>/releases/download/<VERSION>/overfog-manager-installer.run.sha256" \
  -o overfog-manager-installer.run.sha256
sha256sum -c overfog-manager-installer.run.sha256
chmod 0755 overfog-manager-installer.run
./overfog-manager-installer.run --check
```

Run the installer without `--check` only after reviewing its inventory and
group choices. It never replaces sing-box configuration as part of manager
installation.

## Offline installation

Copy `overfog-manager-installer.run` to `/tmp` on the router, verify its hash
against the release checksum, and run the same `--check` command. The bundle is
self-contained and does not require GitHub during installation.
