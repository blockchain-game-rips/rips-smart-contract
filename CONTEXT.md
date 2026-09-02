# Context

Glossary of domain terms. Definitions only — no implementation detail.

## Preset

A named, long-lived offer a user can enter. A preset is what the product
advertises; it outlives the individual rounds played under it.

A preset does not itself hold the numbers. It points at the config that is
current for it, and admins can repoint it at a new one.

## Config

The frozen parameters of a round: currency, entry price, entry cap, duration,
protocol fee, and the payout tiers.

A config is immutable once stored. Updating a preset stores a new config and
repoints the preset at it, so a rip already filling keeps the terms it started
under. This is why a preset and a config are separate things: the preset is the
identity, the config is the terms.

## Rip

One round played under a preset. A rip is created when someone enters and no
rip is currently filling, and it holds the entries sold so far plus the
randomness that decides payouts.

A rip ends in one of two ways. It sells out — entries sold reach the config's
entry cap — which lets anyone ask for randomness; once that randomness arrives,
payouts can be claimed. Or it becomes refundable, and entrants take their money
back instead: either it ran out of time without selling out, or randomness was
asked for and never arrived.

A preset has at most one rip filling at a time. The next entry after a rip
sells out or expires starts a fresh one.

## Entry

A single ticket in a rip, and the unit everything is priced and paid in. Users
buy entries, the entry cap counts entries, and a payout is computed per entry.

Every entry has a position within its rip, assigned in purchase order and fixed
for the rip's lifetime. Position is what the randomness maps to a payout, so it
is the entry's identity, not a display detail.

## Entry chunk

A run of consecutive entries recorded by one purchase. Buying entries appends a
chunk holding the first position and how many followed.

A chunk is a storage grouping, not something a user perceives. Users think in
entries; chunks exist because entries bought together are contiguous by
construction, so storing the pair is cheaper than storing each position. A
purchase splits into several chunks when it is larger than the per-chunk cap.

Chunks are also the unit of claiming: a claim walks whole chunks and never part
of one.

## Payout range

The interval between a tier's minimum and maximum payout. Ranks inside the tier
interpolate across it, so a tier with a wide range pays each of its winners a
different amount, and a tier whose range is a single point pays them all alike.

## Claim

Turning an entrant's entries in a fulfilled rip into money. A claim computes
the payout for each entry it covers and sends the total to the recipient.

Claiming also accrues the protocol's fee, sized from what those entries
originally sold for. The fee is not deducted from the payout: a config is only
valid if the payouts it promises and the fee it charges together account for
the entry revenue, so both are already paid for.

A claim is bounded: it covers only as many chunks as the caller allows in one
call, so a large holding is claimed over several calls rather than one. Where it
resumes is not the caller's choice — the contract remembers how far an entrant
got and always continues from there, so claimed chunks are a prefix that only
grows and a gap in the middle cannot exist. Once nothing is left, claiming
fails rather than paying twice.

An entrant may claim their own, and a privileged caller may claim on their
behalf, but the money always goes to the entrant.
