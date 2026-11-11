# klldap

Fork of [lldap/lldap](https://github.com/lldap/lldap), kept only to ship security updates. It is Rust (server) plus Rust/WASM (frontend) and follows upstream's code, not my own conventions. `.github/copilot-instructions.md` is upstream's project guide and is still useful, but its CI section is out of date.

## Scope

- Keep the diff to upstream small, so upstream can still be merged. No refactors, renames or style changes.
- The wiki Go conventions do not apply. The wiki "GitHub Actions Release Workflow" skill applies only where this file does not say otherwise.
- Docs and example configs still name `lldap/lldap` images. Leave them alone unless asked.

## Testing

There is no `cargo` on the host, so run it in Docker from the repo root:

```bash
docker run --rm -v "$PWD:/src" -v klldap-reg:/usr/local/cargo/registry -v klldap-target:/target \
  -e CARGO_TARGET_DIR=/target -w /src rust:1.91-bookworm sh -c '
  rustup component add clippy rustfmt &&
  cargo fmt --check --all &&
  cargo test --locked --workspace &&
  cargo run -q --locked -- export_graphql_schema -o /tmp/s.graphql && diff schema.graphql /tmp/s.graphql &&
  cargo clippy --locked --tests --workspace -- -D warnings'
```

- Frontend: `cargo check -p lldap_app --target wasm32-unknown-unknown`, or `./app/build.sh` for the full build. Cargo tests do not exercise the forms, so test a frontend change in a browser.
- Tests leave a gitignored `e2e_test.db` in the repo root.
- After a dependency change, also build the root `Dockerfile`. CI does not build it, and its cargo-chef step needs the `COPY vendor vendor` line.
- The first push of a new workflow file may not start a run. Check `gh run list` after pushing.

## Dependencies: do not upgrade these

`opaque-ke` stays on 0.7, with `curve25519-dalek` 3, `digest` 0.9, `sha2` 0.9 and `generic-array` 0.14 tied to it. Moving to `opaque-ke` 4 changes the password protocol, so every stored password would stop working. It would need a migration plan first. CVE-2024-58262 is accepted in `.trivyignore` for this reason, and Dependabot ignores these crates.

## Vendored code

`vendor/` holds `yew_form`, because upstream is inactive and pinned an old `validator`. It is outside the workspace, so clippy does not lint it, but `cargo fmt --all` does format it.

## Security scanning

- **Before publishing:** `docker-build-static.yml` blocks on `Cargo.lock` and on the image, for vulnerabilities that have a fix.
- **Daily:** `trivy.yml` scans the published `stable` image and `Cargo.lock`. A failed run mails me.
- **The image scan cannot see Rust crates**, because they are compiled into the binaries. That is why `Cargo.lock` has its own scan.
- **gosu is skipped on purpose:** Trivy flags every gosu release for Go CVEs in code gosu never calls (see gosu's SECURITY.md). Bumping it does not clear the findings.
- Only add to `.trivyignore` with a written reason.

## CI and images

- Images go to `ghcr.io/mnorrsken/klldap`, Debian only, for amd64 and arm64. Tags are `latest`, `latest-debian` and `latest-debian-rootless`, and the same pattern for versions.
- As upstream does, `latest` is the newest build of `main`, and `stable` is the newest `v*` release. The daily Trivy scan checks `stable`.
- Unlike upstream, this fork has no Alpine images, no armv7 and no musl builds in CI. GitHub's runners cannot reach musl.cc, so do not bring back its toolchains or a custom dev image. The root `Dockerfile` is still upstream's Alpine build, and CI does not use it.
- Binaries are glibc, built natively on a runner of each architecture. `build-bin` is pinned to `ubuntu-24.04`, because a runner with a newer glibc than `debian:trixie` would produce binaries that fail in the image. Bump the runner and the base image together.
- The Rust version is pinned by hand. To change it, update all of: `rust-toolchain.toml`, `rust-version` in `Cargo.toml`, and `MSRV` in `docker-build-static.yml` and `rust.yml`.

## Releases

- Unlike my other repos, the version is in source. Bump it in `server`, `app`, `crates/auth` and `crates/validation`, and update `Cargo.lock`.
- The CHANGELOG heading format is `## [X.Y.Z] YYYY-MM-DD`.
- A `v*` tag builds the images and creates a **draft** GitHub release, which has to be published by hand.
