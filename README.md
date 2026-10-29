# llm-boost

Coloca notebooks Lenovo LOQ/Legion com GPU NVIDIA no modo de máxima performance para LLM local, guiado por um agente de IA.

Testado em: **Lenovo LOQ Essential 15IRX11 (83UX) + RTX 5050 Laptop**, WSL2 no Windows 11. Veja [profiles/](profiles).

## Com um agente de IA (recomendado)

```bash
git clone https://github.com/FlavianMF/llm-boost && cd llm-boost
```

Abra seu agente (Claude Code, Codex, OpenCode, Gemini/Antigravity) neste diretório e diga:

> Siga o AGENTS.md: detecte o hardware, me entreviste sobre a demanda da GPU e aplique o necessário.

## Manual

WSL2:

```bash
./install.sh            # adiciona os helpers ao ~/.zshrc / ~/.bashrc
llm-boost detect        # hardware, GPU e perfis compatíveis
llm-boost llm           # aplica (abre o UAC)
llm-boost status
llm-boost restore       # volta ao estado original salvo
gpu-stat / gpu-watch
```

Windows nativo: `powershell -ExecutionPolicy Bypass -File scripts\Set-LenovoBoost.ps1 [-Detect | -Status | -Profile llm | -Profile restore]`

## O que o perfil `llm` faz

Plano de energia Equilibrado, modo térmico Performance, Dynamic Boost (15 W no 83UX) e reset dos clocks da GPU. Detalhes e motivos em [profiles/lenovo-loq-15irx11-83ux.md](profiles/lenovo-loq-15irx11-83ux.md).

O script recusa máquinas sem perfil (os IDs WMI variam por modelo). O `AGENTS.md` descreve como validar e adicionar um novo.

## Fora deste repo

Build do llama.cpp para sm_120a, `llm-serve`, variáveis do Ollama e `.wslconfig` continuam nos dotfiles.
