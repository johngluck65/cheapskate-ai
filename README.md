# cheapskate-ai
# dev‑rig checker  

A lightweight, read‑only script that verifies your personal development environment (OrbStack/Docker + Ollama + Open WebUI + OpenRouter) without making any changes.

---

## Table of Contents
- [Prerequisites](#prerequisites)  
- [Quick start](#quick-start)  
- [What the script checks](#what-the-script-checks)  
- [Environment variables](#environment-variables)  
- [Interpreting the output](#interpreting-the-output)  
- [Troubleshooting](#troubleshooting)  
- [License](#license)

---

## Prerequisites
- macOS (Intel or Apple Silicon)  
- **OrbStack** installed and running *or* any Docker‑compatible runtime (Docker Desktop, Colima, etc.) – the script will auto‑detect which one is active.  
- Docker CLI available in `$PATH` (`docker` command).  
- **Ollama** installed and its API listening on `http://127.0.0.1:11434`.  
- Model `qwen3:8b` present in Ollama (`ollama list`).  
- **Open WebUI** reachable at `http://localhost:3000`.  
- `curl` and `awk` (standard on macOS).  
- **OpenRouter API key** (optional, only for the authentication test) – provide via the `OPENROUTER_API_KEY` environment variable.

---

## Quick start
```bash
# Make the script executable (once)
chmod +x scripts/check-dev-rig.sh

# Run the check‑only mode
./scripts/check-dev-rig.sh --check-only
```

The script exits with status `0` when every checked component is healthy; a non‑zero exit status indicates at least one issue.

---

## What the script checks
| Component | Check performed | Success condition |
|-----------|----------------|-------------------|
| Docker‑compatible engine | `docker info` | Returns daemon info without error |
| Runtime detection | Looks for OrbStack (`orb status`) and Docker context | Reports whether OrbStack, Docker Desktop, or a generic Docker‑compatible engine is active |
| Ollama | HTTP GET to `http://127.0.0.1:11434/api/tags` | Returns 200 OK |
| Model `qwen3:8b` | Parses output of `ollama list` (plain text) | Finds a line where the first column equals `qwen3:8b` |
| Open WebUI reachability | HTTP GET to `http://127.0.0.1:3000/` | Returns 200 OK |
| Open WebUI model list (optional) | HTTP GET to `http://127.0.0.1:3000/api/models` (requires no auth) | Returns JSON containing an entry with `"id"` or `"name"` equal to `qwen3:8b` |
| OpenRouter authentication (if key supplied) | HTTP GET to `https://openrouter.ai/api/v1/models` with `Authorization: Bearer $OPENROUTER_API_KEY` | Returns 200 OK |

**The script never installs, pulls, starts, stops, or deletes anything.** It is safe to run as often as you like.

---

## Environment variables
| Variable | Purpose | Example |
|----------|---------|---------|
| `OPENROUTER_API_KEY` | Your OpenRouter API key (only used for the optional authentication test). Do **not** hard‑code it in the script. | `export OPENROUTER_API_KEY=sk-or-…` |
| `OPENWEBUI_URL` *(optional)* | Override the default Open WebUI base URL. | `export OPENWEBUI_URL=http://127.0.0.1:8080` |

If `OPENROUTER_API_KEY` is not set, the OpenRouter authentication step is skipped and reported as a warning.

---

## Interpreting the output
Each line is prefixed with one of:

- `PASS:` – the check succeeded.  
- `WARN:` – a non‑fatal issue was detected (script continues).  
- `FAIL:` – a required check failed; the script will exit with status 1 after summarizing all failures.  

At the end you’ll see either:

```
Preflight passed. No changes were made.
```
or  
```
Preflight failed. No changes were made.
```

followed by the exit code.

---

## Troubleshooting common failures
| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `FAIL: No reachable Docker‑compatible API` | OrbStack/Docker not running or Docker CLI not in `$PATH` | Start OrbStack (`open -a OrbStack`) or Docker Desktop; ensure `docker` works in a terminal. |
| `FAIL: ollama command not found` / `FAIL: Ollama is installed, but its API is not responding` | Ollama not installed or daemon not running | `brew install ollama` (or follow Ollama install instructions) then `ollama serve` in the background. |
| `FAIL: qwen3:8b is not installed` | Model not pulled or name mismatch | Run `ollama pull qwen3:8b`. Verify with `ollama list`. |
| `FAIL: Open WebUI is not responding at http://localhost:3000` | Container stopped or wrong port | Start the container (`docker start open-webui` or via OrbStack UI) and confirm the port. |
| `WARN: OPENROUTER_API_KEY is not set; skipping OpenRouter authentication test` | Key not supplied (expected if you don’t want to test auth) | Export the key if you wish to test: `export OPENROUTER_API_KEY=...` |
| `WARN: Open WebUI /api/models returned HTTP 401/403` | Open WebUI requires login to view the model list | Log in to Open WebUI in your browser; the checker can’t query the list without auth, but if you see the model in the UI dropdown it’s loaded. |
| `WARN: Could not reach Open WebUI's /api/models endpoint` | API path changed or server not ready | Wait a few seconds for Open WebUI to finish starting; check its logs. |

---

## License
This script is released under the MIT License – see the accompanying `LICENSE` file for details.

--- 

*Happy checking!*
