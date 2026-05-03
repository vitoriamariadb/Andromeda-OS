# BIOS Checklist — Reaplicar todas as configs caso CMOS limpe

**Placa:** Gigabyte B450M S2H | **BIOS:** F67d (09/2024) | **CPU:** Ryzen 7 5800X
**Última aplicação:** 2026-05-02 — todas validadas em stress 30min sem WHEA.

> Configs BIOS ficam na NVRAM da placa-mãe — imunes a updates do Pop!_OS ou
> Windows. Só morrem se: bateria CR2032 acabar, Clear CMOS, ou recovery
> automática após 3 falhas de POST. Esse arquivo é a fonte-de-verdade pra
> reaplicar tudo.

---

## Como entrar
1. Reinicia
2. Aperta **Del** (ou F2) repetidamente durante o POST
3. Se cair em "Easy Mode", aperta **F2** pra **Advanced Mode**

---

## 1. M.I.T → Advanced Frequency Settings
- CPU Clock Ratio = **Auto** (NÃO setar fixo)

## 2. M.I.T → Advanced Memory Settings
| Configuração | Valor |
|---|---|
| Extreme Memory Profile (X.M.P.) | **Profile1** |
| DRAM Power Down Mode | **Disabled** |

## 3. M.I.T → Advanced CPU Settings
| Configuração | Valor |
|---|---|
| Global C-State Control | **Enabled** |
| Power Supply Idle Control | **Typical Current Idle** |

## 4. M.I.T → Advanced CPU Settings → AMD Overclocking
> Se sumir, procura em `AMD CBS → NBIO Common Options → SMU Common Options`.

**Precision Boost Overdrive:**
| Configuração | Valor |
|---|---|
| Precision Boost Overdrive | **Advanced** |
| PBO Limits | **Manual** |
| → PPT Limit (W) | **110** |
| → TDC Limit (A) | **75** |
| → EDC Limit (A) | **130** |
| Platform Thermal Throttle | **Auto** |
| PBO Scalar | **1x** |
| Max CPU Boost Clock Override | **Negative -100 MHz** |

**Curve Optimizer:**
| Configuração | Valor |
|---|---|
| Curve Optimizer | **Per Core** |
| Cores 0-3 | **Negative -15** |
| Cores 4-7 | **Negative -20** |

> Validado em stress 30min multi + 10min single sem WHEA. Não baixar mais.

## 5. M.I.T → Smart Fan 5

**CPU Fan (Custom):**
| Temp | % |
|---|---|
| 30°C | 30% |
| 50°C | 50% |
| 70°C | 80% |
| 80°C | 100% |

**System Fan 1, 2, 3, 4, 5 (Custom):**
| Temp | % |
|---|---|
| 30°C | 40% |
| 50°C | 70% |
| 70°C | 100% |

## 6. BIOS Features
- Fast Boot = **Enabled**
- Secure Boot = **Disabled**
- CSM Support = **Disabled**

## 7. Settings → Miscellaneous
**Aplica em ordem:**
1. Above 4G Decoding = **Enabled** ← PRIMEIRO
2. Re-Size BAR Support = **Auto** ← só aparece após Above 4G
3. SVM Mode = **Enabled**
4. AMD RAIDXpert2 = **Disabled** ← deixa OFF (dual-boot AHCI)

> Se Re-Size BAR não aparecer: salva (F10), reboot, entra de novo. Aparece.

## 8. Salvar
**F10 → Yes → Save & Exit** → cai direto no Pop!_OS.

---

## Ganhos esperados com tudo aplicado
- BAR1 GPU: 256MB → 8GB (ReBAR ativo, +5-15% em jogos)
- RAM: 2666 (JEDEC) → 3800 MT/s (XMP)
- CPU sustained: Tctl ~70-72°C com PBO Manual 110W (vs 84°C com Motherboard)
- Curve -15/-20: undervolt sem perda de boost
- Curve -15/-20 + PBO 110W: -10 a -15°C VRM, -12 a -14°C CPU sustained

## Recovery se travar
1. Aguarda 3 tentativas (placa entra recovery sozinha)
2. Limpar CMOS: tira tomada → tira CR2032 10s → power 10s → 30s → recoloca
3. Restaurar BootOrder após CMOS clear:
   ```bash
   sudo efibootmgr -o 0001,0000,000A,000C,000E
   ```
4. Reaplica tudo daqui.

---

## Validar pós-reboot
```bash
overclock-healthcheck.sh
```
Instalado em `/usr/local/bin/` pelo ritual-aurora-self-heal v3.3 (fonte:
`~/.config/zsh/scripts/overclock-healthcheck.sh`). Valida 12 seções: kernel
cmdline, USB power, SCSI/AHCI link PM, xHCI PCI runtime PM, systemd services,
udev rules, SMBus/RGB, autostart, self-heal timer, BIOS state (ReBAR, RAM,
WHEA), sensores, last self-heal run.

Esperado: `RESUMO: 24+ pass | 0 fail | 0-2 warn` (warns são checks BIOS que
pedem sudo — pra eliminá-los: `sudo overclock-healthcheck.sh`).

Se `[FAIL]` em SCSI/AHCI: o drop-in
`/etc/systemd/system/com.system76.PowerDaemon.service.d/99-restore-storage-pm.conf`
sumiu — rodar `sudo /usr/local/sbin/ritual-aurora-self-heal.sh` pra reinstalar.
