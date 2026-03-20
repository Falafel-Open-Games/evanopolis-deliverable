# Web Wrapper Screen Specs

This document describes the minimum responsibilities of each likely wrapper
screen before UI implementation begins.

## 1. Landing

Goal:
- let the user immediately understand the two entry paths

Primary actions:
- create room
- join with invite

Inputs:
- optional `game_id` or referral parameters from URL

Must communicate:
- this is the online game entrypoint
- users can create or join a specific room

Fallback action:
- manual room-code entry should exist, but should be visually secondary to the
  invite-link path

Error states:
- none beyond basic load failure

## 2. Auth Step

Goal:
- get the player authenticated with the wallet-signature flow trusted by the
  backend

Primary actions:
- connect wallet
- sign message
- retry

Must communicate:
- expected network for this environment
- why signing is needed
- whether the user is continuing toward create or join

Presentation note:
- this does not need to be a dedicated route
- it can be an inline state, modal, or focused full-page step inside create or
  join flow

States:
- wallet missing
- wrong network
- waiting for wallet approval
- waiting for signature
- auth success
- auth failure
- token expired later and needs refresh

## 3. Create Room

Goal:
- create a room with the minimum supported settings

Primary actions:
- create room

Inputs:
- supported room options such as `player_count`

Must communicate:
- what kind of room will be created
- what happens after creation

Success result:
- returned `game_id`
- next step moves to invite/share state

## 4. Invite Ready

Goal:
- let the creator share the room clearly and continue toward play

Primary actions:
- copy invite link
- open join preview
- continue

Must communicate:
- the room exists
- this link is how another player joins the same game
- any referrer context that should be preserved in the link

## 5. Join / Invite Confirmation

Goal:
- confirm to the invited user what room they are about to join

Primary actions:
- continue to play
- go back

Inputs:
- `game_id` from URL
- room lookup result

Must communicate:
- this invite is valid
- this is a join flow, not room creation
- what must happen before launch

Error states:
- missing `game_id`
- room not found
- room unavailable by future policy

Manual-entry note:
- this same confirmation screen can also be reached from fallback room-code
  entry after successful lookup

## 6. Payment Step Placeholder

Goal:
- complete the required payment step before launch

Primary actions:
- approve
- pay/play
- retry verify
- continue after success

Must communicate:
- why payment is needed
- what network/token is being used
- what room the payment applies to
- that payment completion is required before entering the match

Error states:
- insufficient allowance
- rejected transaction
- verification failed
- payment not found or not confirmed

## 7. Launch Handoff

Goal:
- hand the player into the graphical client with the correct parameters

Primary actions:
- launch game

Must communicate:
- the player is about to enter the actual game client
- which room they are entering

Inputs handed off:
- JWT
- `game_id`
- game-server endpoint

## 8. Invalid Room / Recovery

Goal:
- handle broken or expired invite flows cleanly

Primary actions:
- return home
- create a new room
- re-open invite if corrected

Must communicate:
- what went wrong in plain language
- what the user can do next
