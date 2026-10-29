# Helpers para WSL2 (bash ou zsh). Carregue com: source <repo>/shell/llm-boost.sh
_LLMB_ROOT="${LLM_BOOST_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)}"
_LLMB_PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
_LLMB_SMI=/usr/lib/wsl/lib/nvidia-smi

gpu-stat()  { "$_LLMB_SMI" --query-gpu=pstate,clocks.mem,clocks.sm,power.draw,memory.used,utilization.gpu --format=csv "$@"; }
gpu-watch() { gpu-stat -l "${1:-1}"; }

# llm-boost [llm|restore|status|detect]   (padrao: llm)
llm-boost() {
  local win flag=() cmd="${1:-llm}"
  win="$(wslpath -w "$_LLMB_ROOT/scripts/Set-LenovoBoost.ps1")" || return 1
  case "$cmd" in
    llm|restore) flag=(-Profile "$cmd") ;;
    status)      flag=(-Status) ;;
    detect)      flag=(-Detect) ;;
    *) echo "uso: llm-boost [llm|restore|status|detect]" >&2; return 2 ;;
  esac
  "$_LLMB_PS" -NoProfile -ExecutionPolicy Bypass -File "$win" "${flag[@]}" || return $?
  [[ "$cmd" == llm || "$cmd" == restore ]] && gpu-stat
}
