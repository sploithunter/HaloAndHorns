# Creator Hub funnels — 2026-08-24 2:00 PM MDT

Source: Roblox Creator Hub → Analytics → Funnels for Halo and Horns
(universe 10307183003). Machine-readable copy:
[2026-08-24_creator_hub_funnels.json](2026-08-24_creator_hub_funnels.json).
Screenshots saved beside this file.

This is the **published** 14-step onboarding funnel. It does **not** include
the 32 combat-training beats from local retention v7. Step names last
changed 2026-08-23, so the 28-day and 1-day windows still mix the older
fight-before-Resonance order.

## Why first quest looks like the cliff

First quest / First Steps / first area sat after tutorial complete. Those
goals are optional. A sequential onboarding funnel therefore reports
"tutorial finishers who did not do the first quest" as an 75–90% drop.
That is useful, but it is a poor comparison with the rest of the path.

After this snapshot, onboarding ends at Rally. Optional goals move to the
named **Activation** funnel, which starts at join.

## Last 7 days

- Users: 7,812
- Total conversion: 0.24%
- Biggest drop: step 12 First quest complete (84.65% churn)

| # | Step | Users | Step % | Churn | Total % |
|---|---|---:|---:|---:|---:|
| 1 | Joined game | 7812 | 100.00 | 0.00 | 100.00 |
| 2 | Hatch first egg | 5032 | 64.41 | 35.59 | 64.41 |
| 3 | Mine crystals | 4748 | 94.36 | 5.64 | 60.78 |
| 4 | Grow team | 3119 | 65.69 | 34.31 | 39.93 |
| 5 | Build squad | 1968 | 63.10 | 36.90 | 25.19 |
| 6 | Bind Resonance | 1063 | 54.01 | 45.99 | 13.61 |
| 7 | Cast Resonance | 890 | 83.73 | 16.27 | 11.39 |
| 8 | Enhance Resonance | 661 | 74.27 | 25.73 | 8.46 |
| 9 | Win first fight | 515 | 77.91 | 22.09 | 6.59 |
| 10 | Use battle brew | 477 | 92.62 | 7.38 | 6.11 |
| 11 | Use Rally / Complete | 391 | 81.97 | 18.03 | 5.01 |
| 12 | First quest complete | 60 | 15.35 | 84.65 | 0.77 |
| 13 | First steps complete | 20 | 33.33 | 66.67 | 0.26 |
| 14 | First area unlocked | 19 | 95.00 | 5.00 | 0.24 |

Tutorial-only conversion (join → Rally): **5.01%**.

## Last 28 days

- Users: 9,653
- Total conversion: 0.54%
- Biggest drop: step 12 First quest complete (75.66% churn)

Older step order (fight / brew / Rally before Resonance) is still visible
in this window.

| # | Step | Users | Step % | Churn | Total % |
|---|---|---:|---:|---:|---:|
| 1 | Joined game | 9653 | 100.00 | 0.00 | 100.00 |
| 2 | Hatch first egg | 6148 | 63.69 | 36.31 | 63.69 |
| 3 | Mine crystals | 5710 | 92.88 | 7.12 | 59.15 |
| 4 | Grow team | 3894 | 68.20 | 31.80 | 40.34 |
| 5 | Build squad | 2548 | 65.43 | 34.57 | 26.40 |
| 6 | Win first fight | 1513 | 59.38 | 40.62 | 15.67 |
| 7 | Use battle brew | 1150 | 76.01 | 23.99 | 11.91 |
| 8 | Use Rally | 863 | 75.04 | 24.96 | 8.94 |
| 9 | Bind Resonance | 693 | 80.30 | 19.70 | 7.18 |
| 10 | Cast Resonance | 633 | 91.34 | 8.66 | 6.56 |
| 11 | Use Rally / Complete | 534 | 84.36 | 15.64 | 5.53 |
| 12 | First quest complete | 130 | 24.34 | 75.66 | 1.35 |
| 13 | First Steps complete | 58 | 44.62 | 55.38 | 0.60 |
| 14 | First area unlocked | 52 | 89.66 | 10.34 | 0.54 |

## Last 1 day

- Users: 4,128
- Total conversion: 0.12%
- Biggest drop: step 12 First quest complete (89.93% churn)

| # | Step | Users | Step % | Churn | Total % |
|---|---|---:|---:|---:|---:|
| 1 | Joined game | 4128 | 100.00 | 0.00 | 100.00 |
| 2 | Hatch first egg | 2580 | 62.50 | 37.50 | 62.50 |
| 3 | Mine crystals | 2388 | 92.56 | 7.44 | 57.85 |
| 4 | Grow team | 1447 | 60.59 | 39.41 | 35.05 |
| 5 | Build squad | 871 | 60.19 | 39.81 | 21.10 |
| 6 | Win first fight | 488 | 56.03 | 43.97 | 11.82 |
| 7 | Use battle brew | 364 | 74.59 | 25.41 | 8.82 |
| 8 | Use Rally | 297 | 81.59 | 18.41 | 7.19 |
| 9 | Bind Resonance | 222 | 74.75 | 25.25 | 5.38 |
| 10 | Cast Resonance | 203 | 91.44 | 8.56 | 4.92 |
| 11 | Enhance Resonance / Complete | 139 | 68.47 | 31.53 | 3.37 |
| 12 | First quest complete | 14 | 10.07 | 89.93 | 0.34 |
| 13 | First Steps complete | 5 | 35.71 | 64.29 | 0.12 |
| 14 | First area unlocked | 5 | 100.00 | 0.00 | 0.12 |

## Published vs local monitoring

Creator Hub already charts `LogOnboardingFunnelStepEvent`. There is no
separate Hub form to fill in. The long combat-training onboarding list and
the Activation named funnel (`LogFunnelStepEvent`) are in source and will
appear as new funnel steps **after this build is published**. Compare
cohorts by `placeVersion`.
