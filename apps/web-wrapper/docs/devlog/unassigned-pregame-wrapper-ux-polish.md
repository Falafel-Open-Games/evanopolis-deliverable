# Unassigned - Pre-Game Wrapper UX Polish

## Status

Planned.

## Context

The current wrapper pages were intentionally built as live wireframes.

That was the right tradeoff for the earlier delivery phase:

- get auth, room creation, invite lookup, payment, and launch handoff working
- keep the UI explicit and easy to debug
- avoid spending time on surface polish before the real browser flow existed

That phase is mostly over now.

The public stack now reaches a real graphical client, and the in-match
experience has moved far enough toward a polished professional game that the
pre-game browser flow is now the obvious visual and UX mismatch.

Today, the landing and invitation surfaces still read more like functional
mockups than the actual front door to the game. The payment sequence is also
too fragmented for a player-facing flow: the current path can require separate
actions for allowance approval, allowance checking, payment submission, and
payment verification, which makes the entry step feel procedural instead of
guided.

The next wrapper polish slice should close that gap without turning the wrapper
into an over-abstracted frontend redesign project.

## Goal

Deliver the first polished pre-game wrapper pass so that:

- landing and invite-entry pages feel visually aligned with the quality bar of
  the graphical client
- the wrapper no longer looks like an intentionally grayscale wireframe
- the payment step becomes a clearer guided flow instead of a cluster of
  separate low-level actions
- the player can always tell what stage of entry they are currently in
- the underlying auth, invite, payment, and launch behavior stays explicit and
  robust

## Proposed Shape

- define a wrapper visual direction that clearly borrows from the game’s
  established style guide rather than inventing a disconnected web aesthetic
- refresh the landing and invite pages first, since they set the tone for the
  whole browser flow
- replace the multi-button payment sequence with one primary guided action that
  advances the player through the next required payment step
- add a visible progress/status interface above or around that primary action
  so the player can see the current stage:
  - approve allowance when needed
  - confirm allowance readiness
  - submit match payment
  - verify payment
- keep technical detail available through clear status messaging, but avoid
  exposing the flow as four unrelated operator-style controls

## In Scope

- establish a polished visual treatment for:
  - the wrapper landing page
  - the invite/join page
  - the payment panel within the join flow
- align wrapper typography, color, framing, and panel treatment with the
  design standards already visible in the live game client
- simplify the current payment UI into a more guided single-primary-action
  flow
- expose clear progress messaging for each payment phase
- preserve useful failure states for:
  - wrong network
  - wallet not connected
  - allowance transaction failure
  - payment transaction failure
  - verification failure
- keep the flow understandable on both desktop and mobile
- add a manual validation checklist for visual and behavioral verification

## Out Of Scope

- changing the authoritative payment contract or backend verification boundary
- redesigning the gameplay client itself
- broad marketing-site content strategy beyond what the wrapper entry pages
  need
- speculative animation-heavy brand work detached from the game’s existing
  visual language
- replacing clear runtime feedback with opaque “magic” automation

## Acceptance Criteria

- the landing page no longer reads as a placeholder or internal wireframe
- the invite page feels like part of the same product as the graphical client
- the payment step presents one obvious primary next action instead of four
  loosely related buttons
- players can see which payment phase they are in before, during, and after
  wallet interaction
- payment and verification failures still surface clearly without trapping the
  player in an ambiguous state
- the wrapper remains readable and testable during real local and staging
  browser validation

## Notes On Implementation

This slice should improve presentation and flow clarity without weakening the
current explicit runtime model.

The wrapper should continue to own:

- wallet/auth entry state
- room creation and invite lookup state
- payment orchestration
- launch handoff into the graphical client

The graphical client should continue to own:

- the actual in-game experience
- gameplay presentation and interaction once launched

For the payment UX specifically, the safest product shape is likely:

- one visible progress rail or staged status block
- one primary CTA whose label changes based on the next required step
- optional secondary details for advanced/debug context only when needed
- explicit terminal success and failure states

The important constraint is that “single button” should mean “single guided
entrypoint for the next required step,” not “hide the real state machine.”

If the implementation reveals that some phases must still remain separately
retryable, keep that behavior internally while preserving one obvious default
player action in the UI.

## Manual Validation Checklist

1. Open the wrapper landing page locally and confirm the page feels consistent
   with the current game presentation quality rather than a grayscale mockup.
2. Create a room and confirm the creator-facing flow remains clear after the
   visual refresh.
3. Open an invite link and confirm the invite/join page communicates room-entry
   context clearly.
4. Enter the payment flow and confirm there is one obvious primary action for
   the current required step.
5. Confirm the payment progress UI clearly distinguishes:
   - allowance required
   - allowance ready
   - payment in progress
   - verification in progress
   - payment complete
6. Force at least one recoverable failure and confirm the player gets a clear
   explanation plus an obvious retry path.
7. Repeat the flow on a narrow/mobile viewport and confirm the staged payment
   interface remains understandable.
8. Launch into the graphical client and confirm the visual transition from
   wrapper to game feels product-consistent.

## Deferred Follow-Up

After this milestone, later slices can focus on:

- stronger landing-page art direction or marketing copy
- richer motion and transition polish between wrapper steps
- deeper waiting-room polish once the pre-game browser surfaces are aligned
- broader design-system extraction if repeated patterns stabilize enough to
  justify it
