# Physical-Device Verification

## Purpose

Verify that ChatGPT continues running on a closed-lid MacBook, that ChatGPT Remote works from an iPhone on a separate network, and that stopping Lid Awake restores normal sleep behavior.

## Preconditions

- Connect the MacBook to external power.
- Sign in to the same ChatGPT account and workspace on the Mac and iPhone.
- Start ChatGPT and Lid Awake on the Mac.
- Place the Mac on a desk or another ventilated surface. Never run this test in a bag, on bedding, or on a sofa.

## Keep Awake verification

1. Press **Keep Mac Awake** in Lid Awake.
2. Confirm the red **Keeping Mac Awake** state and healthy Power, ChatGPT, and Safety Monitor indicators.
3. Run the following command and verify `SleepDisabled 1`:

   ```bash
   pmset -g | grep SleepDisabled
   ```

4. Close the MacBook lid completely and wait two minutes.
5. Disable Wi-Fi on the iPhone and switch to 4G or 5G.
6. Select the Mac in ChatGPT Remote and confirm that sending to an existing thread or starting a new thread succeeds.

## Safe release verification

1. Open the lid and press **Return to Normal Mode**, or quit Lid Awake.
2. Within 30 seconds, verify `SleepDisabled 0`:

   ```bash
   pmset -g | grep SleepDisabled
   ```

## Localization verification

Repeat the open-lid UI journey in English and Japanese. Verify the state title, description, button, three readiness cards, safety stop, setup failure, and helper failure. Do not switch languages or relaunch the app during an active Remote session unless interruption is acceptable.

## Hard failures and recovery

- Do not close the lid when Lid Awake displays an error.
- If Normal Mode does not restore and `SleepDisabled` remains `1`, run the following command and approve administrator access:

  ```bash
  sudo pmset -a disablesleep 0
  ```

- Stop the test after an external-power disconnect, a `serious` or `critical` thermal state, or loss of helper status.
- One successful connection proves the basic path only. Run an overnight test under the same conditions before relying on continuous travel access.

## Historical evidence: 2026-09-01

- ChatGPT Remote succeeded after the lid had been closed for two minutes and the iPhone switched from Wi-Fi to 4G.
- The Mac then reported `SleepDisabled 1`; helper status reported schema 2, reason `active`, `isBlockingSleep true`, and thermal state `nominal`.
- Normal app termination restored `SleepDisabled 0`.

This evidence predates the localization commit and cannot verify the localized build.
