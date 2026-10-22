
#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${LIBRECHAT_DIR:-$HOME/repos/LibreChat}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
ask() {
  local answer
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}
backup() {
  [[ ! -e "$1" ]] || cp -p "$1" "$1.bak.$STAMP"
}
has_model() {
  ollama list | awk 'NR > 1 {print $1}' | grep -Fxq "$1"
}

trap 'printf "\nFailed at line %s. Check the error above.\n" "$LINENO" >&2' ERR

[[ "$(uname -s)" == Darwin ]] || die "macOS is required."

# 1. Homebrew and Git
if ! command -v brew >/dev/null 2>&1; then
  ask "Install Homebrew?" || die "Homebrew is required."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  [[ -x /usr/local/bin/brew ]] && eval "$(/usr/local/bin/brew shellenv)"
  command -v brew >/dev/null 2>&1 || die "Complete Homebrew PATH setup and rerun."
fi

command -v git >/dev/null 2>&1 || brew install git

# 2. OrbStack and Docker CLI
if [[ ! -d /Applications/OrbStack.app &&
      ! -d "$HOME/Applications/OrbStack.app" ]]; then
  ask "Install OrbStack?" || die "OrbStack is required."
  brew install --cask orbstack
fi

if ! command -v docker >/dev/null 2>&1; then
  brew install docker docker-compose
fi

command -v docker >/dev/null 2>&1 || die "Docker CLI is missing."
docker compose version >/dev/null 2>&1 ||
  die "Docker Compose is missing."

open -a OrbStack 2>/dev/null || true

for _ in {1..30}; do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
docker info >/dev/null 2>&1 ||
  die "OrbStack's Docker engine isn't responding."

# 3. Ollama
if ! command -v ollama >/dev/null 2>&1; then
  ask "Install Ollama?" || die "Ollama is required."
  brew install --cask ollama
fi

open -a Ollama 2>/dev/null || true

for _ in {1..30}; do
  curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1 ||
  die "Ollama isn't responding."

# 4. Clone or reuse LibreChat
if [[ -e "$REPO" && ! -d "$REPO/.git" ]]; then
  die "$REPO exists but isn't a Git checkout."
fi

if [[ ! -d "$REPO/.git" ]]; then
  mkdir -p "$(dirname "$REPO")"
  git clone https://github.com/LibreChat-AI/LibreChat.git "$REPO"
fi

cd "$REPO"

if [[ -n "$(git status --porcelain)" ]]; then
  die "LibreChat has uncommitted changes. Commit/stash them before running this script."
fi

[[ -f docker-compose.yml ]] || die "Missing docker-compose.yml."
[[ -f .env.example ]] || die "Missing .env.example."

# 5. Environment file; never replace an existing .env
if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 600 .env
else
  say "Preserving existing .env."
  chmod 600 .env
fi

# 6. Optional OpenRouter key
if ! grep -q '^OPENROUTER_KEY=.' .env; then
  if ask "Configure OpenRouter?"; then
    printf "API key (input hidden; Return to skip): "
    read -r -s OPENROUTER_KEY
    printf '\n'

    if [[ -n "$OPENROUTER_KEY" ]]; then
      backup .env
      sed -i '' '/^OPENROUTER_KEY=/d' .env
      printf 'OPENROUTER_KEY=%s\n' "$OPENROUTER_KEY" >> .env
    fi
    unset OPENROUTER_KEY
  fi
fi

# 7. Install the required local model only if missing
if ! has_model qwen3:8b; then
  ask "Download qwen3:8b? This requires several GB." ||
    die "A local model is required for the Ollama endpoint."
  ollama pull qwen3:8b
fi

if ! has_model gpt-oss:20b; then
  if ask "Also download the much larger gpt-oss:20b model?"; then
    ollama pull gpt-oss:20b
  fi
fi

# 8. Configure endpoints while preserving unrelated YAML keys.
# Ruby's YAML writer reformats YAML and removes comments; backups are made.
backup librechat.yaml
backup docker-compose.override.yml

ruby -ryaml -e '
path = "librechat.yaml"
cfg = File.exist?(path) ? (YAML.load_file(path) || {}) : {}
cfg["version"] ||= "1.3.17"
cfg["cache"] = true unless cfg.key?("cache")
cfg["endpoints"] ||= {}
cfg["endpoints"]["custom"] ||= []
list = cfg["endpoints"]["custom"]

models = ["qwen3:8b"]
models << "gpt-oss:20b" if `ollama list`.lines.drop(1).any? {
  |line| line.split.first == "gpt-oss:20b"
}

def upsert(list, endpoint)
  i = list.index { |x| x.is_a?(Hash) && x["name"] == endpoint["name"] }
  i ? list[i] = list[i].merge(endpoint) : list << endpoint
end

upsert(list, {
  "name" => "Ollama",
  "apiKey" => "ollama",
  "baseURL" => "http://host.docker.internal:11434/v1/",
  "models" => {"default" => models, "fetch" => false},
  "titleConvo" => true,
  "titleModel" => "current_model",
  "modelDisplayLabel" => "Ollama"
})

if File.read(".env").match?(/^OPENROUTER_KEY=.+$/)
  upsert(list, {
    "name" => "OpenRouter",
    "apiKey" => "${OPENROUTER_KEY}",
    "baseURL" => "https://openrouter.ai/api/v1",
    "models" => {"default" => ["openrouter/free"], "fetch" => true},
    "titleConvo" => true,
    "titleModel" => "openrouter/free",
    "dropParams" => ["stop"],
    "modelDisplayLabel" => "OpenRouter"
  })
end

File.write(path, YAML.dump(cfg))
' || die "Could not update librechat.yaml."

# 9. Mount configuration and use the documented Apple Silicon MongoDB image.
ruby -ryaml -e '
path = "docker-compose.override.yml"
cfg = File.exist?(path) ? (YAML.load_file(path) || {}) : {}
cfg["services"] ||= {}
cfg["services"]["api"] ||= {}
cfg["services"]["mongodb"] ||= {}
cfg["services"]["mongodb"]["image"] = "mongo:4.4.18"

volumes = cfg["services"]["api"]["volumes"] ||= []
mounted = volumes.any? do |v|
  (v.is_a?(Hash) && v["target"] == "/app/librechat.yaml") ||
  (v.is_a?(String) && v.end_with?(":/app/librechat.yaml"))
end

unless mounted
  volumes << {
    "type" => "bind",
    "source" => "./librechat.yaml",
    "target" => "/app/librechat.yaml",
    "read_only" => true
  }
end

File.write(path, YAML.dump(cfg))
' || die "Could not update the Compose override."

# 10. Validate the combined configuration before starting
docker compose config -q ||
  die "Compose configuration is invalid. Review the error and backups."

# 11. Start LibreChat
say "Starting LibreChat in OrbStack"
docker compose up -d
sleep 8
docker compose ps

# 12. Verify basic availability
if ! docker compose ps --status running --services | grep -qx api; then
  docker compose logs --tail=100 api || true
  die "LibreChat API is not running."
fi

if ! curl -fsS --max-time 10 http://localhost:3080/ >/dev/null; then
  docker compose logs --tail=100 api || true
  die "LibreChat did not respond on port 3080."
fi

printf '\nLibreChat responds at http://localhost:3080\n'
printf 'Create your account in the browser if this is a fresh install.\n'
printf 'Test a local Qwen chat and, if configured, an OpenRouter chat.\n'
printf 'This script does not configure memory or Obsidian retrieval.\n'
printf '\nLogs: cd "%s" && docker compose logs -f api\n' "$REPO"

