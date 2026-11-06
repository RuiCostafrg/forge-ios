# Local CI — `gh-signoff` (Linux only)

Run the Swift checks on your own Linux machine and post a green `signoff/tests`
commit status with [basecamp/gh-signoff](https://github.com/basecamp/gh-signoff).

Use it when free Actions minutes run out — or as a fast pre-push gate. This lane
covers **Linux only**: the Swift package suite (`swift test`) and the
model/project validator. The Xcode/simulator build (`xcodebuild build-for-testing`)
is an Apple-only step and stays in GitHub Actions.

## Setup (Linux)

```bash
gh auth login
gh extension install basecamp/gh-signoff
```

Toolchains: a Swift toolchain that runs on Linux (distro packages or swift.org
tarballs), Python 3.

## Usage

```bash
scripts/local-ci.sh                # stages: tests
scripts/local-ci.sh --no-signoff   # checks only, no statuses posted
```

Push your commits first: `gh signoff` only attests pushed work. A failing stage
posts a red `signoff/tests` status automatically.

## Optional: make sign-off a merge requirement

```bash
gh signoff install tests
gh signoff uninstall
```
