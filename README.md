# cataggar/llvm-project

A personal mirror of [LLVM](https://llvm.org) plus the CI that builds
Zig-oriented prebuilt LLVM toolchains.

## Branches

- **`main`** — a mirror of the upstream source from
  [github.com/llvm/llvm-project](https://github.com/llvm/llvm-project).
  Synced occasionally; carries no local changes.
- **`mirror`** (default) — release and CI tooling only, no LLVM source. This
  is an **orphan branch** holding the GitHub Actions workflows and Copilot
  instructions for this fork.

## CI / tooling on this branch

- **`.github/workflows/build-zig-llvm.yml`** — builds the Zig-oriented prebuilt
  LLVM toolchains (`llvm-zig-<version>-<target>`). The workflow checks out
  `llvm/llvm-project` at the requested `llvmorg-*` upstream tag and builds it.
  Releases are tagged `llvm-zig-<version>` (or `llvm-zig-<version>-p<N>` for
  patched releases). See cataggar/llvm-project#4 and cataggar/llvm-project#13.
- **`patches/<release-tag>/NNNN-*.patch`** — optional patches applied in
  lexicographical order (`git apply --check` then `git apply`) after checking
  out `llvmorg-<version>`.
- **`.github/copilot-instructions.md`** — repository instructions for GitHub
  Copilot.

## What the build produces

Per-target archives published as a GitHub Release named after the release tag
(e.g. `llvm-zig-22.1.2`, whose LLVM source comes from `llvmorg-22.1.2`):

| Target                | Runner            | Archive  |
| --------------------- | ----------------- | -------- |
| `x86_64-linux`        | ubuntu-24.04      | `tar.xz` |
| `aarch64-linux`       | ubuntu-24.04-arm  | `tar.xz` |
| `x86_64-windows-msvc` | windows-2025      | `zip`    |
| `aarch64-macos`       | macos-15          | `tar.xz` |

Asset name: `llvm-zig-<version>-<target>.{tar.xz,zip}`. No `.sha256` sidecars —
GitHub publishes a built-in SHA-256 digest on every asset.

The `x86_64-linux` and `aarch64-linux` builds also publish
`llvm-tools-<version>-<target>.tar.xz`, a tools-only archive containing
`llvm-nm`, `llvm-objcopy`, `llvm-objdump`, `llvm-readelf`, and `llvm-strip`.
It is staged from the same LLVM install tree, without a second compilation.

## Build configuration

- Projects: `clang;lld` only, `CMAKE_BUILD_TYPE=Release`.
- Unix: compiled with **Zig as the C/C++ compiler**
  (`cataggar/zig@v0.17.0-dev.704+b8cb78023`), installed in CI via
  [`ghr`](https://github.com/cataggar/ghr) and minisign-verified. `zig cc`
  cross-compiles the `*-musl` Linux targets.
- Windows: MSVC with static CRT (`/MT`).
- No external deps: zlib, zstd, libxml2, terminfo all OFF (empty stub
  `libz`/`libzstd` are created so downstream `find_package` is satisfied).
- Tests / docs / benchmarks / examples OFF. Tool binaries **ON**
  (`LLVM_BUILD_TOOLS`/`LLVM_BUILD_UTILS`/`CLANG_BUILD_TOOLS`/`LLD_BUILD_TOOLS`),
  then `bin/` is slimmed to just the toolchain binaries Bun needs (clang,
  clang++, clang-cl, llvm-ar, llvm-ranlib, llvm-lib, ld.lld, lld-link,
  llvm-strip, llvm-rc, dsymutil, …) so the archive stays under GitHub's 2 GB
  release-asset limit. Shared libs, `libexec/`, `share/` are pruned; the static
  libs link directly into the tools (`LLVM_BUILD_LLVM_DYLIB=OFF`).

## Running the build

Trigger from the GitHub Actions UI (`workflow_dispatch`) on the `mirror` branch:

- **tag**: `llvm-zig-22.1.2` or `llvm-zig-22.1.8-p1` — the release tag. The
  LLVM source is checked out from the matching `llvmorg-<version>` upstream
  tag (stripping any `-p<N>` patch suffix), while asset names retain the full
  `<version>-p<N>` string (e.g. `llvm-zig-22.1.8-p1-<target>`).
- **target**: leave empty for all, or one target to rebuild just that one
- **tools_only**: default false. Set true with an explicit `x86_64-linux` or
  `aarch64-linux` target to add only a new tools archive to an existing release.
  This uses the same build recipe and stages tools before pruning, but skips
  full-distribution archive creation and upload. It fails if the tools asset
  already exists and never replaces existing assets.

### Patched releases (`llvm-zig-<version>-p<N>`)

Store patches on `mirror` under `patches/<release-tag>/NNNN-*.patch` (for
example, `patches/llvm-zig-22.1.8-p1/0001-X86-check-frame-index-displacement-on-i386.patch`).
During the build:

1. `llvm/llvm-project` is checked out at `llvmorg-<version>`.
2. Every `patches/<release-tag>/NNNN-*.patch` file is verified with
   `git apply --check` and applied in order with `git apply`. A `-p<N>` tag
   with no matching patches, or any patch that does not apply cleanly, fails
   the job.
3. Patched releases never `--clobber` existing release assets — changing the
   patch set or rebuilding an already-uploaded target requires bumping `-p<N>`.
4. Release notes record the upstream `llvmorg-<version>` tag and commit SHA,
   plus each applied patch's file name, SHA-256, and tracking issue.

For example, backfill the ARM64 Linux tools archive without replacing any
existing 22.1.8 assets:

```sh
gh workflow run build-zig-llvm.yml --repo cataggar/llvm-project --ref mirror \
  -f tag=llvm-zig-22.1.8 -f target=aarch64-linux -f tools_only=true
```

Tools-only publication checks that existing asset IDs, sizes, and digests stay
unchanged, compares the new GitHub digest with the local archive SHA-256, and
exercises the published package via `ghr` on a native runner. The run summary
records archive sizes, source/workflow commits, the Zig version, and digests.

Or push a `llvm-zig-*` (or `llvmorg-*`) tag whose commit carries this workflow.

## Consuming it

**Zig (static libs):**

```sh
zig build -Dstatic-llvm --search-prefix <extracted llvm-zig dir>
```

Downstream `cataggar/zig` (`libc17-704`, which pins `find_package(llvm 22)`)
fetches `llvm-zig-22.1.2-<target>` from this repo's releases.

**Bun (`buz`) toolchain:** point the toolchain search at
`<extracted llvm-zig dir>/bin`. Bun invokes the Clang/LLD tool binaries
directly (it does not link any LLVM library).

**LLVM command-line tools:** extract the matching
`llvm-tools-<version>-<target>.tar.xz` asset and invoke the tools from its
`bin/` directory. The tools archive does not contain the static development
libraries, headers, CMake metadata, or Clang/LLD tools from the full package.

Use **ghr v0.8.1 or later** so the `llvm-readelf` and `llvm-strip` symlink
aliases are exposed as commands. On native ARM64 Linux, explicitly install
only the tools archive with:

```sh
ghr install cataggar/llvm-project/llvm-tools-22.1.8-aarch64-linux.tar.xz@llvm-zig-22.1.8
llvm-nm --version
```
