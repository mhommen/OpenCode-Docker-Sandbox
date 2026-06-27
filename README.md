# OpenCode Docker Sandbox

Run the OpenCode AI coding CLI inside a hardened Docker container while using your local or remote Ollama server.

This project is meant for developers who want to experiment with local coding agents without giving them direct access to the host system.

## Why this exists

AI coding agents are useful, but they can also execute commands, edit files, install tools, and make mistakes very quickly.

Running an agent directly on your host machine can feel uncomfortable, especially when testing new models, tools, or workflows.

This sandbox provides a practical middle ground:

* OpenCode runs inside a Docker container
* only the selected project directory is mounted
* files are written with your host UID/GID
* Ollama still runs on the host or another reachable machine
* the container runs as a non-root user
* privilege escalation tools such as `sudo`, `su`, and `pkexec` are removed
* Linux capabilities are dropped by the launcher

It is not a perfect security boundary, but it reduces the blast radius for local agent experimentation.

## What is included

The image currently includes:

* Ubuntu 26.04 base image
* Node.js 22
* .NET 9 SDK and runtimes
* Python 3
* common build tools
* Neovim as the default editor
* OpenCode CLI via the `opencode-ai` npm package
* Ollama CLI support

The Ollama server is not started inside the container. The container connects to an Ollama server running on the host or on another reachable machine.

## Requirements

You need:

* Docker
* an Ollama server reachable from the container
* at least one model pulled in Ollama
* a project directory you want to work on

Example:

```sh
ollama pull <model-name>
```

## Quick start

Clone the repository:

```sh
git clone https://github.com/mhommen/OpenCode-Docker-Sandbox.git
cd OpenCode-Docker-Sandbox
```

Build the image:

```sh
./build-image.sh
```

Start OpenCode in a project directory:

```sh
./ocsb.sh ~/projects/my-app
```

The project directory is mounted into the container at:

```text
/source
```

OpenCode starts inside that directory.

## Using a remote Ollama server

By default, the launcher uses:

```text
http://host.docker.internal:11434
```

You can override this with `-o` or `--ollama`:

```sh
./ocsb.sh -o http://192.168.1.10:11434 ~/projects/my-app
```

This is useful when Ollama runs on another machine in your local network.

## How it works

The launcher script:

1. checks the project directory
2. mounts it into the container as `/source`
3. creates a temporary OpenCode configuration
4. points OpenCode to the Ollama OpenAI-compatible API
5. starts the container as a non-root user
6. drops container capabilities
7. starts OpenCode inside the mounted project

The entrypoint then queries Ollama for available models and uses the first detected model as the default OpenCode model.

## Security model

This sandbox is designed to reduce risk when experimenting with local AI coding agents.

It does this by:

* running as a non-root `developer` user
* matching the host UID/GID to avoid root-owned files on the host
* mounting only the selected project directory
* removing `sudo`, `su`, `sudoedit`, `sudoreplay`, and `pkexec`
* dropping Linux capabilities through the launcher
* keeping the Ollama server outside the container
* avoiding direct access to your full home directory

## Important limitations

This is not a strong isolation boundary for hostile code.

Docker containers are useful isolation layers, but they are not virtual machines. A determined attacker, a malicious dependency, or a container escape vulnerability may still be dangerous.

Use this project as a practical safety layer for local experimentation, not as a guarantee that untrusted code is harmless.

In particular:

* the mounted project directory can be modified by the agent
* network access is still available inside the container
* commands can still run inside the container
* secrets inside the mounted project may be visible to the agent
* Docker itself must be trusted

For stronger isolation, consider a VM, microVM, disposable development environment, or a dedicated machine.

## Repository layout

| Path                       | Purpose                                               |
| -------------------------- | ----------------------------------------------------- |
| `Dockerfile`               | Defines the sandbox image                             |
| `build-image.sh`           | Builds the image with your host UID/GID               |
| `ocsb.sh`                  | Starts the container for a selected project directory |
| `scripts/oc-entrypoint.sh` | Discovers Ollama models and starts OpenCode           |

## Custom image name or tag

The helper scripts support custom image names and tags through environment variables.

Example:

```sh
IMAGE_NAME=opencode-sandbox IMAGE_TAG=test ./build-image.sh
```

Run it with the same values:

```sh
IMAGE_NAME=opencode-sandbox IMAGE_TAG=test ./ocsb.sh ~/projects/my-app
```

## Troubleshooting

### OpenCode starts, but no Ollama model is found

Make sure Ollama is running:

```sh
ollama list
```

Check that the Ollama API is reachable:

```sh
curl http://localhost:11434/api/tags
```

When using a remote Ollama server, pass the URL explicitly:

```sh
./ocsb.sh -o http://192.168.1.10:11434 ~/projects/my-app
```

### Files are owned by the wrong user

Rebuild the image on the machine and user account where you want to use it:

```sh
./build-image.sh
```

The image bakes in your current UID/GID during build.

### The agent cannot access files outside the project

That is intentional.

Only the selected project directory is mounted into `/source`. Start the sandbox with a different directory if you want to expose a different project.

## Suggested use cases

This project is useful for:

* trying OpenCode with local Ollama models
* comparing local coding models
* letting an agent work on a throwaway branch
* experimenting with generated code in a limited environment
* avoiding direct agent access to your host system

## Not recommended for

This project is not intended for:

* running malicious code safely
* processing highly sensitive secrets
* isolating production credentials
* replacing a proper VM or hardened sandbox
* giving untrusted agents unrestricted internet access

## License

MIT

