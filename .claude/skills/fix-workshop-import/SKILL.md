---
description: Diagnose and fix broken Steam Workshop-derived .blueprint imports in Scrap Mechanic (LocalBlueprints) — floating/frozen/non-interactive pieces after import. Use whenever the user pulls a new Workshop blueprint and asks to check/fix it, regardless of filename.
---

# fix-workshop-import

Steam Workshop-exported `.blueprint` files dropped into
`Scrap Mechanic/Survival/LocalBlueprints/` are frequently malformed by whatever
export pipeline produced them. This skill is the accumulated diagnostic
checklist and fix set for that recurring problem, built from repeated live
debugging (game log analysis, not guessing) across many pulled creations.

**Do not guess-and-check against the live game.** Every root cause below was
only confirmed by reading an actual game log (`temp.log` or similar) after
several wrong theories failed. If a new symptom shows up that isn't covered
here, ask the user for the relevant game log snippet rather than trying
random JSON edits.

## Known bug classes (check in this order — most common first)

### 1. Missing `"type"` field on body objects — BY FAR the most common

**Symptom:** Creation imports, is visible, but sits frozen a few feet in the
air and cannot be selected/grabbed with the lift tool. Every single Workshop
pull seen so far (6+ separate creations, same and different filenames, both
blueprint schema version 3 and 4) has had this exact defect.

**Cause:** Every object in the top-level `"bodies"` array is missing its
`"type"` key entirely. Valid/working blueprints always have `"type":0` on
every body.

**Fix:** `scripts/fix_missing_type.py` (bundled with this skill) — inserts
`,"type":0` into every body object via bracket-depth text surgery, so the
rest of the file's exact formatting/whitespace/line-endings are untouched.

```bash
python3 ".claude/skills/fix-workshop-import/scripts/fix_missing_type.py" \
  "Scrap Mechanic/Survival/LocalBlueprints/<FILE>.blueprint"
```

(Paths shown relative to repo root — this skill lives at `<repo-root>/.claude/skills/fix-workshop-import/`, one level above the `Scrap Mechanic/` game-files subdirectory.)

### 2. shapeId not registered in shapesets.json manifest

**Symptom:** Import silently does nothing, or the piece using that shapeId
never appears — even though the shape's definition file exists on disk.
Confirmed via game log: `ShapeManager.cpp:XXXX Failed to find shape with
UUID: {...}`.

**Cause:** A file existing under `Objects/Database/ShapeSets/*.json` is not
enough — it must also be explicitly listed in the `shapeSetList` array of
`Scrap Mechanic/Survival/Objects/Database/shapesets.json`.

**Fix:** Add the missing `"$SURVIVAL_DATA/Objects/Database/ShapeSets/<file>"`
entry to that array. This only applies to *custom/modded* shape definitions
(e.g. `custom.json`) — stock shapesets are always already registered, so this
is only relevant if the blueprint references a UUID that traces back to a
custom part you or a mod added.

### 3. Part-level `restrictions` block blocking interaction

**Symptom:** Creation imports fine, is not floating, but specific pieces
can't be lifted/selected/deleted/painted even though everything else on the
same creation works.

**Cause:** The shapeset definition for that part's UUID has one or more of
the 8 `"restrictions"` booleans (`buildable`, `connectable`,
`convertibleToDynamic`, `destructable`, `erasable`, `liftable`, `paintable`,
`usable`) set `false`. This is a property of the part definition itself, not
the blueprint file — it affects every creation using that part, not just the
one just imported.

**Fix:** Locate the part's `restrictions` block by UUID in its `.shapeset`
file and flip the relevant flag(s) to `true`. Verify afterward with
`/delete` or the lift tool in-game.

### Not bugs — seen and ruled out

- A `"dependencies"` array referencing external Steam Workshop content
  (`steamFileId`/`contentId`/`name`/`shapeIds`) is harmless and does not need
  removing.
- Compact (non-pretty-printed) JSON is fine — the game does not require
  pretty printing. `LunarBronco.blueprint` is compact and works.
- Blueprint schema `"version"` of 3 vs 4 alone has no effect on import
  success.
- Nulling/omitting fields like `steering` has no effect on the frozen/floating
  symptom — don't waste a cycle on it.

## Full diagnostic procedure

Run **before and after** any fix, on every newly pulled blueprint. Use
`scripts/diagnose.py`, pointed at the target file and a known-good reference
file of similar complexity (e.g. `LunarBronco.blueprint`, `LunarTank1.blueprint`,
`LunarOreCollector3.blueprint` — anything already confirmed working in-game).

```bash
python3 ".claude/skills/fix-workshop-import/scripts/diagnose.py" \
  "Scrap Mechanic/Survival/LocalBlueprints/<FILE>.blueprint" \
  "Scrap Mechanic/Survival/LocalBlueprints/<KNOWN_GOOD_REFERENCE>.blueprint"
```

It reports, in order:

1. **Version + top-level keys + body/joint counts + missing-`type` count**
2. **Line-ending audit** — CRLF vs lone-LF counts (repo convention is CRLF;
   a large unexpected lone-LF count means something re-saved the file in the
   wrong mode)
3. **shapeId resolution** — every unique `shapeId` referenced by the
   blueprint, checked against the full current shapeset database. The
   database scan understands the three list-key variants shapesets use
   (`partList`, `blockList`, `wedgeList`) — don't reintroduce a scanner that
   only checks one, it will produce false "missing" positives (this happened
   once: a wedge-skin variant's `shapeId` lives in `blockList` inside
   `blocks.shapeset`, referenced by the wedge entry's `blockUuid`, not by a
   `uuid` field in `wedges.shapeset` itself).
4. **Restrictions check** — every resolved shapeId's `restrictions` block,
   flagging any with a `false` value
5. **Structural key-pattern diff** — recursive key comparison of `bodies`
   and `joints` against the reference file, to surface schema anomalies
   beyond the missing-`type` case (e.g. controller/light/container field
   differences are expected variance between different creations, not bugs
   — only flag keys that look structurally wrong, like a missing `type`)
6. **Color validity** — every `color` value must be a 6-char hex string
7. **Position range sanity** — min/max of body `pos.x/y/z`, just eyeballed
   for anything wildly out of a normal build's range

## After applying any fix

1. Re-run `diagnose.py` and confirm the specific issue is resolved and
   nothing else regressed (e.g. `git diff --stat` should show a small,
   focused diff — a large/unexpected line count almost always means a
   line-ending corruption, see below).
2. **CRLF gotcha:** always open the file with `encoding='utf-8', newline=''`
   for both read and write. Opening without `newline=''` silently converts
   the whole file from CRLF to LF and produces a diff hundreds/thousands of
   lines larger than the real change. If `git diff --stat` looks
   suspiciously large after a fix, revert (`git checkout -- <file>`, but
   only after confirming there's no other uncommitted work you'd lose) and
   redo with the correct flag.
3. Commit with a message describing what the diagnostic battery found (not
   just "fixed bug") and commit only the target blueprint file.
4. Push to **both** remotes: `git push origin modded-1.0.2 && git push
   forgejo modded-1.0.2`.
