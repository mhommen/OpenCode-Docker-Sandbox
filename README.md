# opencode-sandbox (ocsb)

A hardened Docker sandbox for running the [OpenCode](https://opencode.ai) AI CLI
against a local [Ollama](https://ollama.com) instance.

## What's inside

- Ubuntu 26.04 base image
- Node.js 22, .NET 9 SDK + runtimes, Python 3, build toolchain
- Neovim (default editor)
- [opencode-ai](https://www.npmjs.com/package/opencode-ai) CLI
- Ollama (installed but not run inside the container; the host's Ollama is used)

The image runs as a non-root `developer` user whose UID/GID match the host, so
files created in `/source` are owned correctly on the host. `sudo`/`su`/`pkexec`
are removed and the container drops all capabilities.

## Build

```sh
./build-image.sh
```

UID/GID are detected from the current user and baked into the image.

## Run

```sh
./ocsb.sh ~/projects/my-app
```

This mounts `~/projects/my-app` into the container at `/source`, generates an
OpenCode config pointing at `http://host.docker.internal:11434`, queries Ollama
for available models, and launches `opencode` using the first model as the
default.

Override the Ollama URL with `-o`:

```sh
./ocsb.sh -o http://192.168.1.10:11434 ~/projects/my-app
```

## Layout

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Image definition |
| `build-image.sh` | Build helper (sets `HOST_UID`/`HOST_GID`) |
| `ocsb.sh` | Container launcher |
| `scripts/oc-entrypoint.sh` | Discovers Ollama models and starts OpenCode |

## Requirements

- Docker
- A reachable Ollama server with at least one model pulled
