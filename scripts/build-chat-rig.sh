#!/usr/bin/env bash
set -euo pipefail

# Minimal setup/start script for an existing LibreChat checkout on macOS.
# It backs up config files before editing them and never overwrites an existing API key.

REPO="$HOME/repos/LibreChat"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS."
[[ -d "$REPO/.git" ]] || die "I can't find a LibreChat git checkout at $REPO. Edit REPO near the top of this script if needed."

# OrbStack provides the Docker-compatible CLI/Compose runtime.
if ! command -v brew >/dev/null 2>&1; then
  die "Homebrew isn't installed. Install it from https://brew.sh, then rerun this script."
fi
if [[ ! -d /Applications/OrbStack.app && ! -d "$HOME/Applications/OrbStack.app" ]]; then
  say "OrbStack not found; installing it."
  brew install --cask orbstack
fi
if ! command -v docker >/dev/null 2>&1; then
  die "OrbStack is installed, but the Docker CLI isn't on PATH. Open OrbStack and enable its Docker CLI integration, then rerun."
fi
if ! command -v ollama >/dev/null 2>&1; then
  say "Ollama not found; installing it."
  brew install --cask ollama
fi

say "Starting OrbStack and Ollama if needed"
open -a OrbStack 2>/dev/null || true
open -a Ollama 2>/dev/null || true

# Wait briefly for the local Ollama API. Don't silently install/start another runtime.
for _ in {1..20}; do
  if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then break; fi
  sleep 2
done
curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1 || die "Ollama isn't responding at localhost:11434. Open the Ollama app and rerun this script."

docker info >/dev/null 2>&1 || die "Docker isn't responding yet. Wait for OrbStack to finish starting, then rerun this script."

say "Pulling your local models (existing models are reused)"
ollama pull qwen3:8b
ollama pull gpt-oss:20b

cd "$REPO"

# Ask for an OpenRouter key without echoing it. Existing .env values are preserved.
if ! grep -q '^OPENROUTER_KEY=.' .env 2>/dev/null; then
  printf '\nOpenRouter is optional. Paste your API key now, or press Return to skip: '
  read -r -s OPENROUTER_KEY
  printf '\n'
  touch .env
  chmod 600 .env
  # Remove any prior empty placeholder before writing the value.
  if grep -q '^OPENROUTER_KEY=$' .env; then sed -i '' '/^OPENROUTER_KEY=$/d' .env; fi
  if [[ -n "$OPENROUTER_KEY" ]]; then
    printf '\nOPENROUTER_KEY=%s\n' "$OPENROUTER_KEY" >> .env
  else
    printf '\nOPENROUTER_KEY=\n' >> .env
  fi
  unset OPENROUTER_KEY
fi

# Merge the two custom endpoints into librechat.yaml, preserving other YAML settings.
# A timestamped backup is made first. Ruby's YAML library is included with macOS Ruby.
if [[ -f librechat.yaml ]]; then
  cp -p librechat.yaml "librechat.yaml.bak.$(date +%Y%m%d-%H%M%S)"
fi
ruby -ryaml -e '
path = "librechat.yaml"
cfg = File.exist?(path) ? (YAML.load_file(path) || {}) : {}
cfg["version"] ||= "1.3.17"
cfg["cache"] = true unless cfg.key?("cache")
cfg["endpoints"] ||= {}
cfg["endpoints"]["custom"] ||= []
custom = cfg["endpoints"]["custom"]

ollama = {
  "name" => "Ollama",
  "apiKey" => "ollama",
  "baseURL" => "http://host.docker.internal:11434/v1/",
  "models" => {"default" => ["qwen3:8b", "gpt-oss:20b"], "fetch" => false},
  "titleConvo" => true,
  "titleModel" => "current_model",
  "modelDisplayLabel" => "Ollama"
}
openrouter = {
  "name" => "OpenRouter",
  "apiKey" => "${OPENROUTER_KEY}",
  "baseURL" => "https://openrouter.ai/api/v1",
  "models" => {"default" => ["openrouter/free"], "fetch" => true},
  "titleConvo" => true,
  "titleModel" => "openrouter/free",
  "dropParams" => ["stop"],
  "modelDisplayLabel" => "OpenRouter"
}
[ollama, openrouter].each do |endpoint|
  index = custom.index { |item| item.is_a?(Hash) && item["name"] == endpoint["name"] }
  index ? custom[index] = endpoint : custom << endpoint
end
File.write(path, YAML.dump(cfg))
' || die "Couldn't update librechat.yaml. Your backup, if one existed, is safe. Check the YAML file manually."

# Ensure Docker Compose mounts the custom endpoint config, without replacing other overrides.
if [[ -f docker-compose.override.yml ]]; then
  cp -p docker-compose.override.yml "docker-compose.override.yml.bak.$(date +%Y%m%d-%H%M%S)"
fi
ruby -ryaml -e '
path = "docker-compose.override.yml"
cfg = File.exist?(path) ? (YAML.load_file(path) || {}) : {}
cfg["services"] ||= {}
cfg["services"]["api"] ||= {}
volumes = cfg["services"]["api"]["volumes"] ||= []
mount = {"type" => "bind", "source" => "./librechat.yaml", "target" => "/app/librechat.yaml"}
unless volumes.any? { |v| v.is_a?(Hash) && v["target"] == "/app/librechat.yaml" }
  volumes << mount
end
File.write(path, YAML.dump(cfg))
' || die "Couldn't update docker-compose.override.yml. Check the file and rerun."

say "Starting LibreChat"
docker compose up -d

printf '\nAll set. Open LibreChat at http://localhost:3080\n'
printf 'Choose the Ollama endpoint for local models, or OpenRouter for cloud models.\n'
printf 'If OpenRouter was skipped, add your key to %s/.env as OPENROUTER_KEY=... and rerun this script.\n' "$REPO"
printf '\nUseful commands:\n  cd ~/repos/LibreChat && docker compose logs -f api\n  cd ~/repos/LibreChat && docker compose down\n'
