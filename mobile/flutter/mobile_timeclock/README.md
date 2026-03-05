# mobile_timeclock

A Flutter kiosk-style time clock app for employees to **verify** and **clock in/out** on a shared device (tablet), with **offline support** and **automatic syncing** when the network returns.

## What this project is

This app is designed to run on a tablet in a workplace and provide a simple, fast punch flow:
- Employee enters their Employee ID on a keypad
- The app verifies the employee (online or from cached roster)
- The employee clocks IN or OUT
- If the web service is unreachable, punches are **queued offline**
- When the connection is back, queued punches **sync automatically**

## What the TimeClock can do (current features)

- **Kiosk / tablet punch UI**
    - On-screen keypad for Employee ID entry
    - Displays current time/date
    - Shows employee name after verification
    - Shows current IN/OUT state and provides a large CLOCK IN / CLOCK OUT action button

- **Employee verification**
    - Uses a cached employee roster when available
    - Can verify employees even when offline (if roster was previously loaded)

- **Clock IN / OUT**
    - Sends punches to the configured ASMX web service when online
    - Shows success messaging and resets the session after punching

- **Offline punching (queue)**
    - If offline or the service is unreachable, punches are **stored locally** and marked pending
    - Pending punch count is displayed on-screen

- **Automatic sync**
    - The app attempts to sync pending punches on a timer
    - Manual “Sync Now” button is available

- **Status checks**
    - Can request and display the employee’s current IN/OUT status when online
    - Falls back to cached status when offline

- **Optional OT / Site code flow (online)**
    - Prompts for an optional code before punching (can be left blank)
    - Validates the code online before allowing the punch (when a code is provided)

- **Punch log (local audit trail)**
    - Every punch attempt is recorded locally with outcome info (online ok / offline queued / blocked / canceled)
    - Log includes employee name/id, timestamp, IN/OUT, and device identifier
    - Log automatically retains roughly **the last 14 days** of entries

- **Admin access (special keypad codes)**
    - `009876` opens **Service Settings** (edit Base URL + Auth token, verify connection, save)
    - `101010` opens **Punch Log** viewer with copy-to-clipboard export (CSV / JSON)

- **Device configuration (deployment-ready)**
    - Base URL, Auth token, and Device ID are stored on-device using Hive
    - Device ID is used as the kiosk identifier for service calls

## Intended purpose

- Provide a reliable time clock kiosk for workplaces
- Keep punches working during network/service interruptions
- Reduce support issues by allowing on-device service configuration and a punch audit log