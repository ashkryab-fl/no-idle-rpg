# Balance Refactoring Summary

2026-10-11. Technical implementation of phases 1–6 is complete, but final balance acceptance is still pending. The current v3 is a candidate with verified mechanics and known deviations. Phase 7, real desktop validation, has not been performed.

## What Was Implemented

- Removed hero levels, XP, and level-up healing. Power now depends on equipment and selected talents.
- Separated currencies: Gold buys four stats through equipment; Books buy specialization.
- Added diminishing returns. Crit chance gains begin to decline at **25%**.
- Implemented six talents in three mutually exclusive pairs. Purchases and selection changes made during a stage take effect on the next attempt.
- Unified x1/x10/MAX, prices, and previews. A zero numeric effect blocks a purchase; a partial batch is charged for its actual count.
- Reworked saves: HP, specialization, an unfinished attempt, and earned rewards are preserved. The current schema is **v10**; old pre-release saves are reset.
- Tuned bosses, the economy, and late enemy growth. Verified protection against paying first-clear/milestone rewards again after death and restart.
- Ran simulations with different activity levels, purchase frequencies, reinvestment, progression walls, mortality, and income sources.

At the end of the refactoring, the analyzer was clean and **238 tests passed**. Two earlier failures remained because sprite manifest files were missing. This is a historical result from before the test suite was reduced and intermediate materials were removed.

## Balance Findings

In the tested scenarios, focusing entirely on one item performs worse than mixed development. Ignoring Helmet or Amulet also noticeably harms late progression. Economy talents are useful in specific contexts, but do not win across every time horizon. Repeated boss farming showed no systematic advantage over progression.

The mixed contextual strategy is close to the best **tested** strategies: its median gap in the main matrix did not exceed 9.52%. This does not prove global optimality.

## Problems and Questions to Investigate

| Problem | What the checks showed | What to investigate |
| --- | --- | --- |
| **Long progression walls** | At 25–75% activity, walls take about **59–63 active minutes** instead of the 10–45 minute target. Elapsed waiting time is even longer. | Separate insufficient survivability from insufficient income. Check Armor availability and late enemy damage growth locally. Making all purchases cheaper already caused progression to become too fast. |
| **Short boss fights** | On day 30 at low activity, bosses take **7–9 seconds**, below the 10–60 second target. | Check boss HP together with damage and rewards. Raising HP alone may make progression walls longer. |
| **Weak overall competitiveness of Crit protection** | Recovery is more often beneficial. Protection reduced death risk by about 7% only in specially selected critical situations. | Check how often these situations occur in normal play. Consider clear stages with elevated critical risk and a useful hint for choosing protection. Further increasing crits for all enemies needs separate justification. |
| **Uncertain late payoff for Gold talents** | First-clear Gold speeds up early Stage 20, but falls behind Boss damage at later checkpoints and is not guaranteed to pay off within six hours. | Define its role: early specialization or a viable late alternative. For the latter, separately check prices and the value of later ranks. |
| **Alternatives unavailable after spending Books** | In 47 of 180 control budgets, there were not enough Books for the required package. Reserving currency enabled the comparison. | Explore saving strategies and the cost of switching branches. This also depends on spending policy, so automatically increasing Books rewards would be premature. |
| **Weak purchase heuristics** | Adaptive and stageAware reached a frontier of 197, versus 266 for balanced. | Evaluate purchases by survivability across the whole stage, number of hits, and time to the next clear. Current heuristics cannot prove that no better strategy exists. |

There is also a difference between a **numerically positive** purchase and one the player can **feel**. Protection against zero delta is implemented, but a very small gain may not change a player's decisions. Measure how long it takes to reach a purchase that meaningfully improves combat or survivability.

## Remaining Work, in Order

1. **Perform desktop validation:** real input/rest, manual purchases, choice readability, and save/quit/restart. Predictions use a model of assumed activity windows; actual delays are unknown.
2. **Clarify the causes of long progression walls**, then run a small targeted grid of changes and compare strategies again.
3. **Check how often useful talent contexts occur naturally**, especially for protection and late First-clear Gold.
4. **Extend the horizon to 60–90 days.** The screening used only three seeds; it shows that rank 10 is reachable but does not prove stable long-term balance.
5. **Close the two asset-test gaps** and separately check Windows runtime if it is part of acceptance.

The priority is to measure the real desktop pace first, then adjust progression walls and talent alternatives. That gives tuning a basis in actual gameplay.
