# Cheapskate AI

A set of conservative macOS installers for three self-hosted AI chat options:

- **Odysseus**: an integrated assistant with persistent memory and a native Apple Silicon launch path.
- **LibreChat**: a multi-provider chat interface.
- **Open WebUI**: a chat interface for Ollama and OpenAI-compatible providers.

The goal is to keep ongoing costs optional, avoid unnecessary installs, and leave existing data alone.

## Before you start

These scripts are for macOS. Apple Silicon is the primary target; Intel support depends on each upstream project.

You need Homebrew. Each installer sources the shared helpers in `scripts/lib/common.sh`, checks for Homebrew, and installs Git with Homebrew if Git is missing. The Odysseus installer also needs Git to clone its checkout. These checks do not install a container runtime, Python, Ollama, or any models.

OrbStack is a good Docker-compatible runtime for the two container-based rigs. Docker Desktop is not required. Start OrbStack before installing LibreChat or Open WebUI.

## Get the repository

```bash
git clone https://github.com/johngluck65/cheapskate-ai.git
cd cheapskate-ai
chmod +x scripts/*.sh
chmod +x scripts/lib/*.sh
```

Each rig installer performs its prerequisite checks directly, so you can use any of the three on a separate Mac without installing another rig or running a separate setup step.

## Install only the rig you want

### Odysseus

```bash
./scripts/build-odysseus-rig.sh
```

The script clones the upstream `main` branch into `~/repos/odysseus` unless `ODYSSEUS_DIR` is set. It does not update or overwrite an existing checkout. After setup, start it with:

```bash
cd ~/repos/odysseus
./start-macos.sh
```

On Apple Silicon, use the native launcher. Docker on macOS runs inside a Linux VM and cannot give Odysseus direct access to Apple's Metal GPU. The upstream launcher handles its Python environment and dependencies. The first run can take a while and may download substantial dependencies.

#### Connect a local model with Ollama

Odysseus is the chat workspace; Ollama runs the model. They are separate programs, and you need to connect them before you can chat with a local model.

1. Install the Ollama macOS app from [ollama.com](https://ollama.com/download/mac), then open it.
2. In Terminal, download a model that fits your Mac's memory. For example:

   ```bash
   ollama pull llama3.1:8b
   ```

   If that model is too large for your machine, choose a smaller one. The official guide includes hardware-based suggestions.
3. In Odysseus, open **Settings** and add a model provider using this base URL:

   ```
   http://localhost:11434/v1
   ```

   This is the address for a native Mac installation. Select the model you downloaded when it appears in Odysseus.

For screenshots, alternative model suggestions, and troubleshooting, follow the [official Odysseus guide to using Ollama](https://odysseusai.dev/ollama). Its Docker networking instructions are not needed for this native macOS setup.

### LibreChat

Start OrbStack, then run:

```bash
./scripts/build-librechat-rig.sh
```

The script clones LibreChat into `~/repos/LibreChat`, creates `.env` from the upstream example only if one does not already exist, and starts the upstream Docker Compose stack. The app is normally at http://localhost:3080.

LibreChat is an interface, not a model. You must configure a provider. Some providers charge for usage. The first Docker start downloads several images and services. Keep at least a couple of GB available to the container runtime. Older Intel Macs without AVX may not support the default MongoDB image.

### Open WebUI

Start OrbStack, then run:

```bash
./scripts/build-openui-rig.sh
```

The script starts the official Open WebUI container at http://localhost:3000 and stores its data in the persistent Docker volume named `open-webui`.

It does **not** install Ollama or download a model. Those are optional and can be installed separately. Open WebUI can also connect to hosted OpenAI-compatible providers. Provider charges are separate from the software.

To use another port:

```bash
OPEN_WEBUI_PORT=3001 ./scripts/build-openui-rig.sh
```

To select a different official image tag:

```bash
OPEN_WEBUI_IMAGE=ghcr.io/open-webui/open-webui:main-slim ./scripts/build-openui-rig.sh
```

## What the scripts will and won't do

- Each installer sources `scripts/lib/common.sh` and performs its prerequisite checks automatically.
- They are safe to rerun in the normal case.
- Existing project checkouts are not pulled, reset, or overwritten.
- Existing LibreChat `.env` files are left alone.
- Existing named containers are started if stopped, not recreated.
- Open WebUI uses a persistent named volume for its data.
- API keys are not embedded in scripts or automatically saved.
- No model is downloaded automatically.
- No container, volume, model, or user data is deliberately deleted.

The installers do not silently install OrbStack or Docker Desktop. You choose and install your Docker-compatible runtime before running LibreChat or Open WebUI.

## Useful upstream documentation

- [Odysseus installation](https://odysseusai.dev/install)
- [LibreChat Docker installation](https://www.librechat.ai/docs/local/docker)
- [Open WebUI quick start](https://docs.openwebui.com/getting-started/quick-start/)
- [OrbStack](https://orbstack.dev/)

## License

MIT. See [LICENSE](LICENSE).
