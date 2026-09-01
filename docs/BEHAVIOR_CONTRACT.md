# Behavior Contract

This document fixes the user-visible behavior that refactoring, localization, and security hardening must preserve. A behavior change requires an agreed issue and an update to this document before code changes.

## Main journey

1. Double-clicking Lid Awake opens one window with one large action button.
2. The default green **Normal Mode** uses standard macOS sleep behavior when the lid closes.
3. Pressing the button while external power is connected starts the mode; first-time setup or a helper update requests administrator approval.
4. The red **Keeping Mac Awake** state appears only after the helper verifies `SleepDisabled 1`.
5. Pressing the button again verifies `SleepDisabled 0` before returning to green **Normal Mode**.
6. Quitting writes a disabled lease and returns to Normal Mode within 30 seconds.

The app follows the macOS language preference. Unsupported languages fall back to English. English and Japanese present the same states and actions without changing the safety policy.

## Safety journey

| Condition | User-visible result | Helper result |
|---|---|---|
| Start without external power | Amber Safety Stop with a power instruction | Do not block sleep |
| External power disconnect while active | Amber Safety Stop | Run `disablesleep 0` within the polling interval |
| `serious` or `critical` thermal state | Amber Safety Stop | Run `disablesleep 0` within the polling interval |
| App crash or force quit | The app disappears | Release after lease expiry, within 30 seconds |
| Helper status is stale for more than 10 seconds | Replace the red state with an error | Do not claim an observed state |
| `pmset` failure, timeout, or verification mismatch | Show an error | Mark state unknown and retry a safe release |
| Mac restart | Do not restore Keep Awake mode | Release on startup, then reject the stale lease |

## Accessibility contract

- State names, descriptions, and icons accompany color.
- Button labels describe the resulting action.
- The app never infers success from a button press; it waits for verified helper state.
- Primary English and Japanese labels must remain within the fixed-window length budgets tested in CI.

## Non-goals

- Wi-Fi, internet, OpenAI, or ChatGPT/Codex availability guarantees
- Closed-lid operation on battery power
- Automatic login, lock-screen bypass, or FileVault bypass
- Automatic restoration after restart
- Network access, telemetry, or automatic updates
