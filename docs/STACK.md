# Stack

Pins for the `master` tree, how this repo uses them, and where they sit
against current stable releases.

Audited **2026-09-25** against `master` commit
`8f045f135ba3c8271595f840bd595a82195f793c` (2026-08-16). The install
truth is [`pixi.lock`](../pixi.lock). The allowed window is
[`pixi.toml`](../pixi.toml). CI pins live in
[`.github/workflows/test.yml`](../.github/workflows/test.yml).

This page follows **stable** releases. Mojo nightlies
(`mojo==1.2.0.dev2026092205` on 2026-09-22, manual at
<https://mojolang.org/nightly/docs/>) are a separate channel.

## What master installs

Workspace `mu` 0.6.0 (`comptime VERSION` in `src/mu/__init__.mojo`).
Pixi lock format 6. One environment, `default`.

| | |
| --- | --- |
| Channels | `https://conda.modular.com/max`, then `conda-forge` |
| Platform | `osx-arm64` only |
| Direct dependencies | `mojo >=1.0.0,<2`, `python ==3.12` |
| PyPI dependencies | none |

Tasks:

| Task | Command |
| --- | --- |
| `mu` | `mojo run -I src src/main.mojo` |
| `build` | `mojo build -I src -o build/mu src/main.mojo`, then copy `src/mu_runtime.py` to `build/` |
| `test` | `mojo run -I src` on every `tests/test_*.mojo` |
| `fmt` | `mojo format src tests` |

`pixi.lock` solves those two direct dependencies into the packages
below. Versions are the locked artifacts, not the manifest range.

| Locked package | Version | Build | Channel | What calls it |
| --- | --- | --- | --- | --- |
| `mojo` | 1.0.0 | `release` | Modular max | `mojo run`, `mojo build`, `mojo format` |
| `mojo-compiler` | 1.0.0 | `release` | Modular max | required by `mojo==1.0.0` |
| `mojo-python` | 1.0.0 | `release` | Modular max | required by `mojo-compiler==1.0.0` |
| `mblack` | 26.5.0 | `release` | Modular max | `mojo format` (`mojo==1.0.0` requires `mblack==26.5.0`) |
| `python` | 3.12.0 | `h47c9636_0_cpython` | conda-forge osx-arm64 | CPython interpreter for `std.python` and `src/mu_runtime.py` |
| `cpython` | 3.12.13 | `py312hd8ed1ab_1` | conda-forge noarch | metapackage; depends on `python >=3.12,<3.13` |
| `python-gil` | 3.12.13 | `hd8ed1ab_1` | conda-forge noarch | metapackage; depends on `cpython 3.12.13.*` |
| `python_abi` | 3.12 | `8_cp312` | conda-forge noarch | ABI constraint for the 3.12 interpreter |

The interpreter package is `python 3.12.0` (conda timestamp
2023-10-03). `cpython 3.12.13` in the same lock is a noarch
compatibility package. It does not upgrade the interpreter.

Everything else in the lock is the conda-forge runtime of that
interpreter (`openssl`, `libffi`, `libsqlite`, …) or the Jupyter client
stack declared by `mojo==1.0.0` (`jupyter_client >=8.6.2,<8.7`, locked
at 8.6.3, plus `jupyter_core`, `pyzmq`, `tornado`, `traitlets`). `src/`
and `tests/` do not import Jupyter.

## How the tree uses it

```text
pixi run …  →  mojo 1.0.0  →  src/**/*.mojo
                    └────→  std.python  →  CPython 3.12.0
                                              └─ src/mu_runtime.py
```

Mojo owns the agent loop, tools, sessions, and CLI. Python owns JSON,
HTTP, SSE, and subprocesses. `src/mu/pyrt.mojo` imports `mu_runtime`
once per process. `mojo build` does not embed that helper, so `pixi run
build` copies `src/mu_runtime.py` next to `build/mu`.

### Mojo standard library

Imports in `src/` and `tests/`. Latest-stable links are the current
stable manual (<https://mojolang.org/docs/>, Mojo 1.1.0 as of the
[releases index](https://mojolang.org/releases/)). The 1.0.0 manual is
the frozen book for the compiler this lock runs. A `/1.1.0/docs/`
prefix returned 404 on the audit date; 1.1.0 is published as the
unversioned stable manual, with nightlies under `/nightly/docs/`.

| Import | Used for | Latest stable | Manual for 1.0.0 |
| --- | --- | --- | --- |
| `std.os`, `std.os.env` | `mkdir`, `getenv`, `setenv` | [os](https://mojolang.org/docs/std/os/) | [os](https://mojolang.org/1.0.0/docs/std/os/) |
| `std.pathlib` | `Path`, `cwd` | [pathlib](https://mojolang.org/docs/std/pathlib/) | [pathlib](https://mojolang.org/1.0.0/docs/std/pathlib/) |
| `std.python` | `Python`, `PythonObject`, `import_module` | [python](https://mojolang.org/docs/std/python/) | [python](https://mojolang.org/1.0.0/docs/std/python/) |
| `std.sys` | `argv` | [sys](https://mojolang.org/docs/std/sys/) | [sys](https://mojolang.org/1.0.0/docs/std/sys/) |
| `std.sys.terminate` | `exit` | [sys](https://mojolang.org/docs/std/sys/) | [sys](https://mojolang.org/1.0.0/docs/std/sys/) |
| `std.io` | `input` in the REPL | [io](https://mojolang.org/docs/std/io/) | [io](https://mojolang.org/1.0.0/docs/std/io/) |
| `std.testing` | `assert_equal`, `assert_true`, `assert_false`, `TestSuite` | [testing](https://mojolang.org/docs/std/testing/) | [testing](https://mojolang.org/1.0.0/docs/std/testing/) |
| `std.tempfile` | `mkdtemp` in tests | [tempfile](https://mojolang.org/docs/std/tempfile/) | [tempfile](https://mojolang.org/1.0.0/docs/std/tempfile/) |

Each `tests/test_*.mojo` file ends with
`TestSuite.discover_tests[__functions_in_module()]().run()`. That is
still the pattern in the [1.1.0 `TestSuite` page](https://mojolang.org/docs/std/testing/suite/TestSuite/)
and the [1.0.0 page](https://mojolang.org/1.0.0/docs/std/testing/suite/TestSuite/).
`pixi run test` launches those files with `mojo run`. It does not call
a separate `mojo test` driver.

CLI manuals: [`mojo run`](https://mojolang.org/docs/cli/run/),
[`mojo build`](https://mojolang.org/docs/cli/build/),
[`mojo format`](https://mojolang.org/docs/cli/format/)
(1.0.0 copies: [run](https://mojolang.org/1.0.0/docs/cli/run/),
[build](https://mojolang.org/1.0.0/docs/cli/build/),
[format](https://mojolang.org/1.0.0/docs/cli/format/)).
`mojo format` is the front end for `mblack`. There is no separate
mblack manual. [PyPI `mblack` 26.5.0](https://pypi.org/project/mblack/26.5.0/)
matches this lock. [PyPI `mojo` 1.1.0](https://pypi.org/project/mojo/1.1.0/)
requires `mblack==26.6.0`.

Python interop, including why a Mojo binary still needs a CPython
runtime: [stable manual](https://mojolang.org/docs/manual/python/),
[1.0.0 manual](https://mojolang.org/1.0.0/docs/manual/python/). The
stable manual requires Python 3.10–3.14 for that bridge. This tree
pins 3.12.

### Python standard library

`src/mu_runtime.py` is the only Python file. Doc links are the
**3.12.14** release manuals (latest stable 3.12 patch, 2026-08-12).
The series alias is <https://docs.python.org/3.12/>.

| Module | Role in `mu_runtime.py` | 3.12.14 manual |
| --- | --- | --- |
| `json` | `dumps` / `loads` for messages, SSE, sessions | [json](https://docs.python.org/release/3.12.14/library/json.html) |
| `urllib.request`, `urllib.error` | chat-completions POST and SSE | [request](https://docs.python.org/release/3.12.14/library/urllib.request.html), [error](https://docs.python.org/release/3.12.14/library/urllib.error.html) |
| `subprocess`, `os` | `bash` tool (`shell=True`, inherited env plus `AI_AGENT` / `MU_*`) | [subprocess](https://docs.python.org/release/3.12.14/library/subprocess.html), [os](https://docs.python.org/release/3.12.14/library/os.html) |
| `sys` | stdin, stdout, stderr | [sys](https://docs.python.org/release/3.12.14/library/sys.html) |
| `time` | retry backoff | [time](https://docs.python.org/release/3.12.14/library/time.html) |
| `datetime` | session id timestamps | [datetime](https://docs.python.org/release/3.12.14/library/datetime.html) |
| `typing` | `Any`, `Callable`, `Iterator`, `TypeVar` | [typing](https://docs.python.org/release/3.12.14/library/typing.html) |

Release notes: [Python 3.12.14](https://www.python.org/downloads/release/python-31214/).
3.12 is in security-fixes-only mode until October 2028 (PEP 693).
3.12.10 was the last 3.12 release with binary installers. conda-forge
still publishes `python 3.12.14` for `osx-arm64` (build
`hd05a0c4_3_cpython`, uploaded 2026-09-03).

### Source map

| Path | Role |
| --- | --- |
| `src/main.mojo` | CLI and REPL |
| `src/mu/agent/` | loop, messages, tools, events |
| `src/mu/ai/` | OpenAI-compatible completer and `--fake` |
| `src/mu/coding/` | filesystem tools, sessions, skills, prompts, config |
| `src/mu/jsonx.mojo`, `src/mu/pyrt.mojo` | Mojo face of the Python runtime |
| `src/mu/plugin.mojo`, `src/mu/coding/active.mojo` | `NullPlugin` on `master` |
| `src/mu_runtime.py` | JSON, HTTP, SSE, subprocess |
| `tests/test_*.mojo` | 12 files, one `TestSuite` each |

`master` does not contain `src/mu/hermes/`. That tree is the `hermes`
branch.

### CI

[`.github/workflows/test.yml`](../.github/workflows/test.yml) runs on
push and pull request to `master` and `hermes`.

| Pin | Value | Kind |
| --- | --- | --- |
| Runner | `macos-14` | GitHub-hosted image label |
| Checkout | `actions/checkout@v4` | floating v4 tag |
| Pixi setup | `prefix-dev/setup-pixi@v0.8.8` | exact action tag |
| Pixi | `pixi-version: v0.41.4` | exact CLI tag |
| Cache | `cache: true` | setup-pixi input |
| Test step | `pixi run test` | pixi task above |

`macos-14` is Apple Silicon, which matches `platforms = ["osx-arm64"]`.
The workflow does not run `pixi run fmt` or `pixi run build`.

## Ours vs latest stable

Checked 2026-09-25. "Latest stable" excludes nightlies and previews.
Moving any of these is a lockfile change plus `pixi run test`, not a
docs edit.

| Piece | This tree | Latest stable | Gap |
| --- | --- | --- | --- |
| Mojo | manifest `>=1.0.0,<2`; lock **1.0.0** (2026-08-11 release, conda package timestamp 2026-08-09) | **1.1.0** (2026-09-17) | One minor. The manifest range allows 1.1. The lock does not. [1.0.0 notes](https://mojolang.org/releases/v1.0.0/), [1.1.0 notes](https://mojolang.org/releases/v1.1.0/), [index](https://mojolang.org/releases/) |
| mblack | **26.5.0**, required by conda `mojo==1.0.0` | **26.6.0**, required by PyPI `mojo==1.1.0` | Tracks the Mojo pin. [26.5.0](https://pypi.org/project/mblack/26.5.0/), [26.6.0](https://pypi.org/project/mblack/26.6.0/) |
| CPython | manifest `==3.12`; lock **3.12.0** `h47c9636_0_cpython` (2023-10-03) | **3.12.14** (2026-08-12); conda-forge `osx-arm64` `python 3.12.14` `hd05a0c4_3_cpython` (2026-09-03) | Fourteen patch releases, including security fixes. Pixi `==` is an exact MatchSpec match, so `==3.12` stays on 3.12.0. A 3.12 line is `3.12.*`. [spec](https://pixi.prefix.dev/v0.81.0/concepts/package_specifications/), [3.12.14](https://www.python.org/downloads/release/python-31214/) |
| pixi CLI in CI | **v0.41.4** (2025-02-19) | **v0.81.0** (2026-09-15) | Local installs are unpinned; only CI is frozen. [v0.41.4](https://github.com/prefix-dev/pixi/releases/tag/v0.41.4), [v0.81.0](https://github.com/prefix-dev/pixi/releases/tag/v0.81.0) |
| `setup-pixi` | **v0.8.8** (2025-04-15) | **v0.10.2** (2026-08-28) | v0.9.0 moved the action to Node 24. v0.10.0 changed the post-cleanup default. [v0.8.8](https://github.com/prefix-dev/setup-pixi/releases/tag/v0.8.8), [v0.10.2](https://github.com/prefix-dev/setup-pixi/releases/tag/v0.10.2) |
| `actions/checkout` | `@v4`, whose newest tag is **v4.4.0** (2026-07-20) | **v7.0.1** (2026-07-20) | Three majors. The v4 tag still receives backports. [v4.4.0](https://github.com/actions/checkout/releases/tag/v4.4.0), [v7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1) |
| GitHub runner | **`macos-14`** | **`macos-26`** (`macos-latest` since the June–July 2026 migration). `macos-15` remains supported | `macos-14` deprecation started 2026-07-06. The image is scheduled to be unsupported on **2026-11-02**. [hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [deprecation](https://github.com/actions/runner-images/issues/13518) |
| Solve platform | `osx-arm64` only | README install line also names Linux | Linux is not a pixi platform in this lock, so `pixi install` there has nothing to solve |

Mojo 1.1 removes the legacy `fn` and `alias` keywords, `@parameter if` /
`@parameter for`, and the `read` argument convention. This tree's
sources use `def` and do not use those forms. That is a reading of the
1.1 changelog, not a test run. `pixi run test` on a 1.1 lock is still
required before bumping.

The current Python feature series is 3.14. Mojo's stable interop
manual allows 3.10–3.14. This repo's manifest stays on the 3.12 line
on purpose. The drift that matters inside that choice is 3.12.0 versus
3.12.14.

## Official manuals

Use these when the tables above are too narrow.

| Topic | Latest stable manual | Manual for what this tree runs |
| --- | --- | --- |
| Mojo | <https://mojolang.org/docs/> (1.1.0) | <https://mojolang.org/1.0.0/docs/> |
| Mojo releases | <https://mojolang.org/releases/> | <https://mojolang.org/releases/v1.0.0/> |
| Pixi | <https://pixi.prefix.dev/v0.81.0/> | <https://pixi.prefix.dev/v0.41.4/> |
| Pixi on GitHub Actions | <https://pixi.prefix.dev/v0.81.0/integration/ci/github_actions/> | action README at [v0.8.8](https://github.com/prefix-dev/setup-pixi/blob/v0.8.8/README.md) (the v0.41.4 book has no matching integration page) |
| `setup-pixi` inputs | [v0.10.2 README](https://github.com/prefix-dev/setup-pixi/blob/v0.10.2/README.md) | [v0.8.8 README](https://github.com/prefix-dev/setup-pixi/blob/v0.8.8/README.md) |
| `actions/checkout` | [v7.0.1 README](https://github.com/actions/checkout/blob/v7.0.1/README.md) | [v4.4.0 README](https://github.com/actions/checkout/blob/v4.4.0/README.md) |
| Workflow syntax | <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax> | same |
| Python 3.12 | <https://docs.python.org/release/3.12.14/> | the locked interpreter is 3.12.0; language docs for that series are the 3.12.14 manuals above |
| conda-forge | <https://conda-forge.org/docs/user/introduction/> | same |
| Modular conda channel | <https://conda.modular.com/max> | same |

`https://pixi.sh/latest/` redirects to `https://pixi.prefix.dev/latest/`.
The versioned URLs above are the pins. The floating `/latest/` book
can move without a release tag.

## Maintenance

Update this file when `pixi.toml`, `pixi.lock`, or
`.github/workflows/test.yml` changes, and when Mojo, pixi, or the
GitHub actions above publish a stable release. A docs refresh records
the new versions. It does not edit the pins.

1. Read `[dependencies]` and `[tasks]` in `pixi.toml`.
2. Read the `default` environment in `pixi.lock` and the package
   entries for `mojo`, `mojo-compiler`, `mojo-python`, `mblack`,
   `python`, `cpython`, and `python-gil`. Quote the artifact version
   and build, not the manifest range alone.
3. Search `src/` and `tests/` for `from std.` and `Python.import_module`.
   Search `src/mu_runtime.py` for `import`.
4. Mojo: the stable table on <https://mojolang.org/releases/>. Ignore
   the nightly row. Confirm <https://mojolang.org/docs/> and
   <https://mojolang.org/1.0.0/docs/> still resolve, and check whether
   a versioned 1.x prefix exists before linking one.
5. pixi: the newest tag on
   <https://github.com/prefix-dev/pixi/releases> and
   <https://github.com/prefix-dev/setup-pixi/releases>. Prefer
   `https://pixi.prefix.dev/vX.Y.Z/` over `/latest/`.
6. Checkout: newest release, and the newest tag on the major this
   workflow names (`v4` today).
7. Python: newest 3.12 security release on python.org, then the
   matching conda-forge `osx-arm64` `python` artifact. Keep the
   "interpreter vs noarch `cpython` metapackage" split explicit.
8. Runners: the hosted-runner table and the macOS 14 deprecation
   issue linked above. `macos-14` is scheduled to fail jobs after
   2026-11-02.
9. Replace the audit date and the `master` commit at the top.

To actually move a pin: change `pixi.toml` or the workflow, run
`pixi lock` (or let `pixi install` update the lock), run
`pixi run test` on `osx-arm64`, then update the tables here in the
same change.
