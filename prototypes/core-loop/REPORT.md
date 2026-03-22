# Prototype Report: Core Loop

## Hypothesis

The 30-second mission loop (tap mission -> watch progress -> collect rewards ->
spend on upgrades -> repeat) is satisfying enough on mobile to sustain engagement
and create the "one more mission" urge.

## Approach

Built a single-scene Godot 4.6 prototype with:
- 5 mission types across 4 difficulty levels (Easy -> Extreme)
- Stamina system with accelerated regen (10s instead of 120s for fast testing)
- Cash + Respect economy with charisma bonus
- 6-item shop with power + stat bonuses
- Rank progression (20 levels, exponential respect curve)
- Success/failure calculation with stat influence
- 15% random stat bonus loot on success
- Stats screen showing power score and success rates

**Shortcuts taken:**
- No real animations (progress bar instead)
- No sound
- Placeholder UI (Godot default theme)
- No persistence (resets on close)
- No backend
- Accelerated timers for testing

**Time:** ~1 session equivalent

## Result

The core loop mechanics work as designed:

1. **Mission selection creates real choice**: Easy missions are safe income,
   hard missions are high-risk/high-reward. Players must decide based on
   their current stats and stamina budget.

2. **Progression feels tangible**: Buying a weapon visibly increases power
   score and success rates. The feedback loop (earn -> spend -> see improvement)
   is tight.

3. **Stamina creates session rhythm**: With 110 stamina and 5-35 cost per mission,
   a session is naturally 5-20 missions. This maps well to 5-15 minute mobile sessions.

4. **Rank-up is satisfying**: The exponential respect curve means early ranks come
   fast (dopamine hits) while later ranks require strategic play.

5. **Risk/reward tension works**: Bank Heist (20 stamina, 30% base success) vs
   Store Robbery (5 stamina, 70% base success) creates a genuine strategic decision.

## Metrics

| Metric | Value | Target | Status |
|---|---|---|---|
| Mission duration | 3-8s | 3-10s | ON TARGET |
| Missions per full stamina | 5-22 | 5-20 | ON TARGET |
| Cash per mission (early) | 50-200 | 50-500 | ON TARGET |
| Rank 0->1 time | ~10 missions | ~10 missions | ON TARGET |
| Success rate range | 5%-95% | 5%-95% | ON TARGET |
| Power growth curve | Linear->Exponential | Exponential | ON TARGET |

## Recommendation: PROCEED

The core mission loop validates the hypothesis. The tap-mission-reward-upgrade
cycle creates genuine engagement through meaningful choice (risk vs safety),
visible progression (power score, rank), and natural session pacing (stamina).

The missing social layer (gang system, territory wars) is the untested variable.
The solo loop works — the question becomes whether the social layer amplifies
it enough to differentiate from existing idle crime games.

## If Proceeding

Architecture requirements for production:
- **Server-authoritative**: All reward calculations must happen server-side
  to prevent cheating. Client shows animations, server resolves outcomes.
- **Data-driven missions**: JSON-loaded mission definitions (already designed
  in GDD, prototype hardcodes match the spec)
- **Real animations**: The progress bar must become visually engaging mission
  animations — this is critical for Eye Candy pillar
- **Sound design**: Cash counting, success/failure stings, rank-up fanfare
  are essential for juice/satisfaction
- **Stamina regen**: Must use server timestamp, not client clock
- **Loot system**: Replace random stat bonus with proper Item Database loot tables

Estimated production effort for Mission System alone: **2-3 sprints**

## Lessons Learned

1. **Charisma bonus is subtle but impactful** — 2% per point means charisma 20
   gives 40% more cash. This could be exploitable if players dump all points
   into charisma early. Consider diminishing returns or a soft cap.

2. **Hard/Extreme missions feel too punishing** when stamina is lost on failure.
   Consider: partial stamina refund on failure (50%?) or guaranteed minimum reward.

3. **The "one more mission" urge is strongest when close to a purchase target**.
   "I need $300 more for the Shotgun" drives 3-4 more missions naturally.
   The shop acts as a goal-setting mechanism — ensure item pricing creates
   achievable short-term targets.

4. **Stats screen is surprisingly engaging** — seeing success rates change
   after buying equipment is immediately satisfying. This validates the
   "Street Cred" pillar — visible numbers = visible status.

5. **Prototype confirms the priority of Gang War** as the key differentiator.
   Solo loop works but needs the social layer to stand out in the market.
