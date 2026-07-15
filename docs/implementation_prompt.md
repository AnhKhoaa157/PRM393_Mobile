# Flutter Completion Prompt — PBMS Mobile

You are completing a Flutter migration of `ParkingManagement_Mobile` for the
backend at `ParkingManagement_BE`. Work only in `PRM393_Mobile`.

## Objective

Deliver a customer mobile app with feature and visual parity for the useful
flows in the Expo source, while using the real backend contract under
`/api/users/*`. Preserve the existing blue/slate design language; do not use
mock data in production screens.

## Backend contract to honor

- Authenticate with `/users/auth/login`, `/register`, `/me`,
  `/forgot-password`, and `/reset-password`.
- Persist the bearer token securely across application restart and restore the
  user via `/users/auth/me`.
- Use `/users/reservations/policy` before reservation creation. Enforce active
  policy, max advance days, max duration, and whole-hour durations locally.
- Use building vehicle types, floors and slots endpoints. Permit the user to
  select an available reservable slot, then send its `slotId`.
- Map parking history fields from the backend schema: `entryTime` and
  `exitTime` (while accepting legacy names when present).
- Support wallet top-up by opening the PayOS `checkoutUrl`; show the payment
  result and refresh wallet state.
- Support notification list, mark-one-read and mark-all-read.
- Support long-term subscription creation, cancellation (with a reason) and
  renewal.
- Support license plate list/add/remove/set-default and profile/password
  updates.
- Provide QR member code and feedback screens when their backend endpoint is
  available.

## UI requirements

- Use the Expo source as the visual reference: curved deep-blue hero blocks,
  white rounded cards, sky-blue primary actions, compact status chips and
  six-item bottom navigation.
- Provide dedicated reusable widgets for cards, empty state, feedback/snackbar,
  date/time picker, notification sheet and slot picker. Avoid putting all UI in
  one file.
- Keep screens accessible, scroll-safe and with loading/error/empty states.

## Definition of done

1. No endpoint or response-field mismatch against the backend routes.
2. No mock production data; loading/error state exists for every API screen.
3. `dart format lib` and `dart analyze lib` complete with no errors.
4. Document API_BASE setup and any platform dependency in README.
