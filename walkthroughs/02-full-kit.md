# Walkthrough 2 — The full kit

> **Not written yet.** Nothing in this walkthrough has been run. It becomes a
> real walkthrough, with captured output, once each step has been done on
> hardware. Until then this is the plan, not instructions.

Add the parts that make the Coralboard useful beyond a sample image: Wi-Fi, the
camera, and the Sense add-on's microphones. Then point the camera at your desk
and talk to it.

**You need:** a board that finished [walkthrough 1](01-zero-to-first-ai.md), plus:

- AMPAK AP12611_M2 Wi-Fi/Bluetooth module (M.2 2230, E-key) and its antenna
- Sense add-on. **It apparently includes a camera** (to confirm which sensor
  and cable), which may make the separate camera below unnecessary.
- Arducam B0033 camera (OV5647), if the Sense camera doesn't cover it. Use the
  **orange 15-to-22-pin cable** that comes with it, not the white 15-to-15:
  wide end on the camera, narrow end on the board.

## Planned steps

1. **Shut down and assemble** (`adb shell poweroff` first): Wi-Fi module into
   M.2 and screw it down, camera onto the CSI port, Sense add-on on top.
2. **Check what Linux sees:** `wlan0` appears; the `ov5647` driver binds on
   `i2c-3` at 0x36 (the device tree already expects it); the Sense mics show up
   as an ALSA capture device (unverified: the demos' READMEs ask for a USB mic).
3. **Wi-Fi:** `wpa_supplicant@wlan0` and `systemd-networkd`, per the
   [Synaptics user guide](https://developer.synaptics.com/docs/developer-kits/coralboard/sl/user-guide),
   so the USB cable is no longer the only link.
4. **Object detection from the camera** (`object_detection/`, YOLOv8).
5. **Voice:** `speech_to_text` and `gemma_translate` with the microphones.
6. **Optional:** `scene_description` (LFM2-VL) describing a camera photo.

## Known going in

From the walkthrough 1 bring-up:

| Bus | Where | Notes |
|---|---|---|
| `i2c-1` | mikroBUS (SM_TW1) | Power-management chip at 0x60 |
| `i2c-2` | Qwiic J8 (TW2), probably | Empty. Confirm with a Qwiic breakout and `i2cdetect -y -r 2`. |
| `i2c-3` | Camera / display | Device-tree nodes for ov5647 (0x36), touch (0x38), 7" panel (0x45) |
| none | 20-pin header I2C (SM_TW0) | Disabled in the stock device tree |

`/` is 99% full after walkthrough 1. Avoid anything that installs to it.
