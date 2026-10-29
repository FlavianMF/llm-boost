# Lenovo LOQ Essential 15IRX11 (83UX) + RTX 5050 Laptop

| Ajuste | Valor | Por que |
| --- | --- | --- |
| Plano de energia | Equilibrado (`381b4222-...`) | Preserva o orçamento dinâmico Intel IPF / NVIDIA Dynamic Boost. Desempenho máximo travou a GPU em 35 W. |
| `SmartFanMode` (`LENOVO_GAMEZONE_DATA`) | `3` (Performance) | 1 = silencioso, 2 = balanceado, 3 = performance. |
| Dynamic Boost (`LENOVO_OTHER_METHOD`, ID `0x02010300`) | `15` W | Soma ao limite base de 65 W. |
| `nvidia-smi -rgc` / `-rmc` | reset | Remove travas manuais de clock e libera o P2 automático. |

Resultado medido: P2 com GDDR7 a 11001 MHz e SM entre 1700 e 2000 MHz.

Requisitos: carregador original na tomada. A leitura WMI exige Admin (UAC).
