# Hero speech

The companion shares one four-second, non-interactive speech bubble for two
localized catalogs in `lib/l10n/app_en.arb`:

- 40 return-to-work quips after a completed rest graph.
- 50 playful break reminders after 40 uninterrupted minutes, then every 3 minutes
  (40, 43, 46, ...). A shuffled bag uses every reminder before repeating and
  avoids repeats across bag boundaries. Speech randomness is independent of
  combat, loot, and rest selection.

`GameSimulation.breakReminder` counts real running time across travel, approach,
combat, reward, death, and respawn phases. Debug speed does not accelerate it.
Only actual rest restarts the 40-minute grace period. Animation previews and
discarded suspend gaps pause the timer without resetting it; encounter resets
and checkpoint restoration also preserve it. A pending rest request during combat
waits for the encounter to finish. The timer is session-only and is not saved.

Speech is hidden during rest, death/respawn, previews, or zero overall opacity.
Hidden events are consumed without replay. Return-to-work speech takes priority
if both events arrive together. Reminders never force the player to rest.
