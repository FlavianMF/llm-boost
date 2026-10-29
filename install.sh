#!/usr/bin/env bash
# Instala os helpers no shell do WSL2 (idempotente) e confere o ambiente.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LINE="source \"$ROOT/shell/llm-boost.sh\"  # llm-boost"

grep -qi microsoft /proc/version || { echo "Fora do WSL2: rode scripts/Set-LenovoBoost.ps1 direto no PowerShell do Windows." >&2; exit 1; }
[[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]] || { echo "powershell.exe do Windows não acessível pelo WSL." >&2; exit 1; }

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$rc" ]] || continue
  grep -qF "# llm-boost" "$rc" || { echo "$LINE" >> "$rc"; echo "Adicionado a $rc"; }
done
echo "Pronto. Abra um novo shell e rode: llm-boost detect"
