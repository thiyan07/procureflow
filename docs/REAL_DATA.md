# ProcureFlow — All Available Real Data (Collected 2026-09-18)

**Storage constraint 6GB — no large models, no datasets downloaded, only lightweight deterministic data.**

## 1. Tamil Nadu Civil Supplies Corporation (TNCSC) — Nodal Agency
- Established 1972 (Govt. of Tamil Nadu), registered Sec 25 Companies Act 1956 (08 Companies Act 2013) 01-Apr-2010, HQ Chennai.
- 33 Regions (1 per revenue district + 2 Chennai), 7,293 permanent + 5,111 seasonal + 5,199 loadmen + 27,845 seasonal loadmen.
- 271 operational godowns, 21 Modern Rice Mills (100 MT/day each, 2100 MT/day total, modernized 3 phases 26.27+32.60+36.00 Cr), 23 MRMs in Cauvery delta + private hullers.
- Paddy procurement seasons: **Kuruvai 01-Oct → 15-Dec**, **Samba 16-Dec → 31-Jul** (TNCSC/proc.html, Tiruvarur dept). Since 01-Oct-2002 Decentralised procurement at MSP + state incentive (Common +50, Grade A +70). Max 1,621 DPCs in KMS 2011-12, 21.10 LMT procured, target 26 LMT.

## 2. MSP — Cabinet Approved (Latest KMS 2026-27, May 13 2026)

**Sources:** `PIB PRID 2260618` May 13 2026 (CCEA chaired PM Modi), `desagri.gov.in MSP Notifications Kharif 2026-27`, `agriwelfare.gov.in Kharif_2026_27_En.pdf`, `S&P Global May13 2026`.

| Crop | Variety | MSP 2026-27 (Rs/qtl) | Cost 2026-27 | Margin |
|---|---|---|---|---|
| **Paddy** | Common | **2441** (+72 vs 2369) | 1627 | 50% |
| **Paddy** | Grade A | **2461** (+72 vs 2389) | — | — |
| Jowar | Hybrid | 4023 | — | — |
| Jowar | Maldandi | 4073 | — | — |
| Bajra | — | 2900 | — | — |
| Ragi | — | 4886* | 282? | 50% |
| Maize | — | 2400 | 1447 | 54% (2024-25) |
| Tur/Arhar | — | 8000 | 4761 | 59% |
| Moong | — | 8682 | 5788 | 50% |
| Urad | — | 7800 | — | — |
| Groundnut | — | 7263 (2025-26) / 6377 (2024-25) | — | — |
| Sunflower | — | 7721 / 6760 | — | — |
| Soyabean Yellow | — | 5328 / 4600 | — | — |
| Sesamum | — | 9846 / 8635 | — | — |
| Nigerseed | — | 9537 / 7734 | — | — |
| Cotton Medium Staple | — | 7710 | — | — |

*Ragi 2025-26 4886 verified; 2026-27 likely same/base — PIB not yet updated for millets in excerpt. Previous KMS 2025-26: Paddy 2369/2389 (`PIB PRID 2131983` Jun 2025, `pib PRID 2200996`), 2024-25: 2300/2320 (`PIB 2026698`). Procurement value 2024-25: 1,223 LMT Rs 3.47 lakh crore, MSP payouts 2014-15→2024-25 Rs 1.06→3.33 lakh crore, farmers 1.84 cr.

## 3. Direct Purchase Centres (DPC) — Real Erode District KMS 2025-26 (as on 12-07-2026, `tncsc.tn.gov.in/en/DPC.html`)

**775 permanent DPCs statewide**. Erode region sample (8 of 30+ Erode DPCs, all Closed for 2025-26 season now):

| Region | Taluk | Village | Opening | Closing | Status | Geo |
|---|---|---|---|---|---|---|
| Erode | Bhavani | Perunthalayur 2 | 11/10/2025 | 19/04/2026 | Closed | 11.462022,77.564306 |
| Erode | Bhavani | Poothapadi | 22/01/2026 | 05/04/2026 | Closed | 11.600918,77.699956 |
| Erode | Erode | Elavamalai | 09/01/2026 | 06/03/2026 | Closed | 11.430405,77.650293 |
| Erode | Erode | Nasiyanur A | 05/01/2026 | 28/02/2026 | Closed | 11.232308,77.275971 |
| Erode | Erode | Perodu | 08/01/2026 | 23/02/2026 | Closed | 11.400287,77.606891 |
| Erode | Erode | Vairapalayam | 19/11/2025 | 18/05/2026 | Closed | 11.359263,77.708585 |
| Erode | Gobichettipalayam | Alukuli | 22/01/2026 | 11/04/2026 | Closed | 11.448425,77.357671 |
| Erode | Gobichettipalayam | Eloor | 26/09/2025 | 20/04/2026 | Closed | 11.509238,77.338364 |
| Erode | Gobichettipalayam | Kalingiyam | 05/01/2026 | 04/02/2026 | Closed | 11.413114,77.357566 |
| Erode | Gobichettipalayam | Kasipalayam | 29/09/2025 | 12/04/2026 | Closed | 11.431647,77.253236 |
| Erode | Kodumudi | Kodumudi | 30/01/2026 | 23/03/2026 | Closed | 11.058988,77.881176 |
| Erode | Kodumudi | Sivagiri | 27/01/2026 | 02/04/2026 | Closed | 11.130408,77.806100 |

**ProcureFlow seeded 4 representative DPCs (active):**
- `c1` TNCSC DPC Bhavani Regulatory Market — Bhavani Taluk/Gobichettipalayam Div — 11.4475,77.6815 — Open 09:00-17:00 counters 3 avg 3m
- `c2` Perundurai RM — Perundurai Taluk/Erode Div — 11.2760,77.5860 — Open 2/4m
- `c3` Sathyamangalam RM — Sathyamangalam Taluk/Gobichettipalayam Div — 11.5054,77.2380 — Busy 4/3m — tiger city 11.5167,77.25
- `c4` Gobichettipalayam RM — Gobichettipalayam Taluk — 11.4536,77.4383 — Open 3/3m (division 11.45361,77.43833)

**e-DPC:** `tncsc-edpc.tn.gov.in` — farmers approach nearest DPC for registration.

## 4. Erode District — Revenue & Agro Statistics (Real)

**Admin (erode.nic.in 2026):** 6,036 km² (10°36′-11°58′N, 76°49′-77°58′E), 2 divisions (Erode/Gobichettipalayam), 10 taluks (Erode, Perundurai, Modakurichi, Kodumudi, Gobichettipalayam, Sathyamangalam, Bhavani, Anthiyur, Thalavadi, Nambiyur), 36 firkas, 375 revenue villages, 14 blocks (Erode 6 villages, Perundurai 29, Bhavani 15 etc), 1 Corp (Erode 11.340889,77.717111), 5 Munc (Bhavani 04256-230556, Gobi, Sathyamangalam, Punjai Puliampatty, Perundurai), 41 Town Panchayats.

**Population (electoral roll Jan 6 2025, Hindu):** 19,77,419 voters (9,55,356M,10,21,871F,192 TG), 2,222 polling stations.

**Agriculture (erode.nic.in/departments/agriculture, TNRTP DDR):**
- Net cultivated 1,56,641 ha; Paddy 25,100 ha, Millet 20,100 ha, Pulses 5,500 ha, Oilseeds 22,900 ha, Cotton 900 ha, Sugarcane 16,000 ha; 70% irrigated, cropping: Wet (Bhavani, Gobi, Sathy…), Dry (Chennimalai), Semi-Arid (Anthiyur).
- Production (2023): Paddy 34,335 ha 1,59,047 MT, Groundnut 16,881 ha 28,596 MT, Banana 12,550 ha 3,93,888 MT, Turmeric 8,912 ha 42,249 MT, Tapioca 7,174 ha 1,77,743 MT.
- Season & Crop Report 2024-25 (Fasli 1434): Tamil Nadu paddy 2.16 Mha (10th India 4.21%), production 7.09 MT (10th 4.72%), 34.66% area; Kar/Kuruvai Apr-Jul declined Fengal cyclone, Samba Aug-Nov +6.87% area +2.91% prod, Navarai Dec-Mar +5.25%/+6.22%.
- Schemes: PMFBY (Maize, Groundnut, Redgram, Ragi, Sesame Kharif; Samba Paddy, Sugarcane Rabi), NFSNM, NADP Paddy, Uzhavar Nala Sevai Maiyam.

**Marketing:** 6 regulated markets (Gobi/Vellankoil etc), Uzhavar Sandhai, Modern Rice Mills 21×100 MT/day list with coords `tncsc.tn.gov.in/en/MRM.html` (Thimmavaram 12.716864,79.956764 … Thirukoilur 11.983615,79.228026), 1,546 fair price shops, 271 godowns.

## 5. TNCSC Tenders (Live Sep 2026, tendersontime.com)
- Casuarina poles 147636988 EMD 134600 02-Sep-2026, Y-cone 147127756 EMD 55600 27-Aug-2026, Black gram 371 MT EMD 240500, Green gram 386 MT EMD 338100, Palmolein 600 lakh pouches EMD 46497000 07-Sep-2026, Jute twine 7250 bales EMD 2253300 21-Aug-2026, Godown road Neliyalam 19-Aug-2026.

## 6. ProcureFlow Real Data Current Usage
- `backend/scripts/seed.py` commodities 5 rates above, centres 4, villages Kavindapadi/Kanjikoil/Kugalur/Perodu etc real firkas, slots 8/day capacity 20, payments computed via real MSP.
- `lib/core/constants/app_constants.dart` mspRates map synced 2441/2461.
- No external datasets downloaded (storage 5.8G).

**Last verified:** 2026-09-18 via `curl /api/v1/centres` 4, `python -m pytest 19 passed`, `flutter build apk --debug` ✓.

