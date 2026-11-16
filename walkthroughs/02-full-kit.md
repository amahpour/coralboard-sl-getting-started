# Walkthrough 2 — The full kit

Add the parts that take the Coralboard beyond a sample image: Wi-Fi, the
camera, and the Sense add-on's microphones. Then get off the USB cable onto
Wi-Fi, run object detection on the live camera, and talk to the board.

Every block of output is real, captured from a bring-up on 2026-11-15. Long
outputs are trimmed where marked with `…`. Each command says where it runs:
**PC** is your Linux machine, **board** is a shell on the Coralboard.

**Time:** about 30 minutes.
**You need:** a board that finished [walkthrough 1](01-zero-to-first-ai.md),
plus:

- AMPAK AP12611_M2 Wi-Fi/Bluetooth module (M.2 2230, E-key) and its antenna
- The Sense add-on (Google calls it the Sensor HAT). It includes a camera
  (OV5647) and two PDM microphones.

---

## Step 1 — What's in the box

| Part | What it adds |
|---|---|
| AP12611_M2 module and antenna | Wi-Fi and Bluetooth, so the board can leave your desk |
| Sense add-on | A camera (OV5647), two PDM microphones, RGB LEDs and a buzzer |

The Sense add-on is the retail version of the Sensor HAT Google handed out at
I/O.

---

## Step 2 — Put it together

**PC:** shut the board down before plugging anything into it:

```bash
adb shell poweroff
```

Unplug USB-C once the red heartbeat stops. Then, following
[Google's guide](https://developers.google.com/coral/products/SL2610-get-started):

1. **Wi-Fi module** into the M.2 slot. Screw it down and attach the antenna.
2. **Camera cable:** into the camera module, then into the board's CSI
   connector, which sits between the two halves of the mikroBUS socket. Lift
   each lock bar, insert the cable, and push the bar back down.
3. **Camera** onto the mounts on the add-on, with the four M1.6 screws.
4. **Add-on** onto the board, camera facing up and out, cable folded under.

Plug USB-C back in and wait for the red heartbeat.

---

## Step 3 — What Linux sees

**PC:** get back online. The board's USB network link comes up with a new name
on your PC every boot (ours went from `enx5a176425fae1` to `enx0a38efc435e2`),
so use the helper from this repo rather than retyping the `nmcli` command:

```bash
scripts/share-usb-network.sh
```

```
==> Host: sharing network on enx0a38efc435e2
    host address: 10.42.0.1/24
==> Board: waiting for ADB
==> Board: requesting a DHCP lease on usb0
    udhcpc: lease of 10.42.0.28 obtained from 10.42.0.1, lease time 3600
==> Board: syncing the clock
    board time: Sun Nov 15 21:26:48 UTC 2026
==> Board: checking internet
    online
```

**PC:** now look at what the board found. Each of these runs one command on the
board through `adb shell`.

```bash
adb shell ls /sys/class/net
```

```
lo
sit0
usb0
wlan0
```

`wlan0` is the Wi-Fi module. Its driver loaded its firmware at boot:

```bash
adb shell 'dmesg | grep -E "43711|wlan0"'
```

```
…
[   22.434737] dhd_bus_download_firmware: firmware path=fw_sd_bcm43711.bin, nvram path=bcmdhd_sd_43711.cal sig path:
…
[   23.461163] Register interface [wlan0]  MAC: 40:fd:f3:ea:18:a2
```

The same log has lines like `sdioh_reset_sdio Failed, no device!` and
`Direct firmware load for filter_ie failed with error -2`. They're harmless:
the interface comes up anyway.

The camera talks to the board over I2C bus 3:

```bash
adb shell i2cdetect -y -r 3
```

```
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
00:                         -- -- -- -- 0c -- -- -- 
10: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
20: -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
30: -- -- -- -- -- -- UU -- -- -- -- -- -- -- -- -- 
…
```

`UU` at 0x36 means the `ov5647` camera driver has claimed the sensor. Use `-r`
with `i2cdetect` on this board: without it, some addresses are skipped.

```bash
adb shell 'for v in /sys/class/video4linux/*; do echo "$(basename $v): $(cat $v/name)"; done'
```

```
v4l-subdev0: camera-isp-subdev.0
v4l-subdev1: dw-mipi-csi.0
v4l-subdev2: ov5647 3-0036
video0: camera-video.0.0
video1: camera-video.0.1
```

Frames come from `/dev/video0`; camera controls like exposure live on
`/dev/v4l-subdev2`.

The microphones are ALSA capture device 2, `dummy-dmic`:

```bash
adb shell arecord -l
```

```
**** List of CAPTURE Hardware Devices ****
card 0: klamathasoc [klamath-asoc], device 0: asoc-i2s2 snd-soc-dummy-dai-0 []
…
card 0: klamathasoc [klamath-asoc], device 1: asoc-i2s3 snd-soc-dummy-dai-1 []
…
card 0: klamathasoc [klamath-asoc], device 2: dummy-dmic snd-soc-dummy-dai-2 []
…
```

---

## Step 4 — Connect Wi-Fi

Following the
[Synaptics user guide](https://developer.synaptics.com/docs/developer-kits/coralboard/sl/user-guide),
create two config files and start the Wi-Fi service.

**Board** (in `adb shell`):

```bash
mkdir -p /etc/wpa_supplicant
```

```bash
printf "ctrl_interface=/var/run/wpa_supplicant\nupdate_config=1\n" > /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

```bash
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

```bash
printf "[Match]\nName=wlan0\n\n[Network]\nDHCP=ipv4\n" > /etc/systemd/network/25-wlan.network
```

```bash
systemctl enable --now wpa_supplicant@wlan0.service
```

```
Created symlink /etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service -> /usr/lib/systemd/system/wpa_supplicant@.service.
```

```bash
systemctl restart systemd-networkd
```

**Board:** see what's in range:

```bash
wpa_cli -i wlan0 scan && sleep 8 && wpa_cli -i wlan0 scan_results
```

**Board:** join your network. Open `wpa_cli`:

```bash
wpa_cli -i wlan0
```

and type these at its `>` prompt, with your own network name and password:

```
add_network
set_network 0 ssid "YourNetwork"
set_network 0 psk "your-password"
enable_network 0
save_config
quit
```

`save_config` stores the password on the board, so it reconnects after a
reboot. Watch for network names with curly apostrophes (`’`): a typed `'`
won't match.

**Board:** check it:

```bash
wpa_cli -i wlan0 status | grep -E "^(wpa_state|ssid|key_mgmt|ip_address)="
```

```
ssid=YourNetwork   # (redacted)
key_mgmt=WPA2-PSK
wpa_state=COMPLETED
ip_address=192.168.68.109
```

**PC:** you can now SSH in over Wi-Fi from any machine on your network, and the
USB cable is down to supplying power:

```bash
ssh root@192.168.68.109
```

> **Security:** `root` has **no password** on the stock image, so anyone on
> your network can log in ([K7](../README.md#k7)). Set one with `passwd` on the
> board if your network isn't just yours.

---

## Step 5 — Object detection

**Board** (over SSH or `adb shell`), with the Python environment from walkthrough 1:

```bash
cd /home/root/sl2610-examples && source .venv/bin/activate && cd object_detection
```

```bash
pip install -r requirements.txt && python setup_demo.py
```

```
[INFO    ] utils.version: Custom repo Synaptics/yolov26n_od has no default version; using its latest (HEAD) revision.
[INFO    ] utils.model_setup: object_detection model files for version latest ready at '/home/root/sl2610-examples/models/Synaptics/yolov26n_od'
```

Those are the last two lines. `setup_demo.py` downloads two sets of models:
YOLOv8 nano (`yolov8-od-nano-320-int8-torq`), which the demo uses by default,
and YOLO26 n/s (`yolov26n_od`), fetched at whatever its latest version is and
only used if you pass it with `--model`.

**Board:** run it on the camera, saving the annotated video:

```bash
python3 run_cli.py --camera-device /dev/video0 --camera-control-device /dev/v4l-subdev2 --output /home/root/od_b.mp4 --json-results /home/root/od_b.json
```

```
…
187 (10.121 ms) person 0.86
```

Each line is a frame number, the NPU inference time, and anything detected.
Press **Ctrl+C** to stop:

```
Interrupted by user.
Done. Processed 188 frames. Output: /home/root/od_b.mp4
```

**PC:** copy the video back to watch it:

```bash
adb pull /home/root/od_b.mp4
```

Two things that differ from the example's README:

- The README's command for the Sensor HAT camera adds `--rotate 180`. That's
  meant for its portrait display setup. With the camera mounted as in Step 1,
  it turns the picture upside down, so leave it off.
  ([Known issue K5](../README.md#k5))
- Stop the demo with Ctrl+C in the foreground. If you start it in the
  background (with `&`), it ignores Ctrl+C and the saved video is never
  finished (`moov atom not found` when you try to play it).

Expect a dim, greenish picture in ordinary room light: the sensor runs with
auto exposure but no white balance. More light helps the detections too.

---

## Step 6 — The microphones

**Board:** record four seconds from the mics (ALSA device `hw:0,2`, from Step 3).
It only takes 24- or 32-bit audio with at least two channels, so ask for that.
(Devices 0 and 1 are I2S inputs with nothing attached; they give `read error:
Input/output error`.)

```bash
arecord -D hw:0,2 -f S32_LE -r 48000 -c 2 -d 4 /home/root/dmic.wav
```

```
Recording WAVE '/home/root/dmic.wav' : Signed 32 bit Little Endian, Rate 48000 Hz, Stereo
```

**PC:** pull it back and play it:

```bash
adb pull /home/root/dmic.wav
```

### Speech to text

Moonshine turns speech into text on the NPU.

**Board:**

```bash
cd /home/root/sl2610-examples/speech_to_text && pip install -r requirements.txt && python setup_demo.py
```

```
[INFO    ] utils.model_setup: Resolving moonshine models: [tiny-en]
[INFO    ] utils.model_setup: moonshine model files for version v2.3.0 ready at '/home/root/sl2610-examples/models/Synaptics/moonshine-tiny-bf16-torq'
```

The demo reads keys as you type, so start it with `adb shell -t`.

**PC:**

```bash
adb shell -t 'cd /home/root/sl2610-examples && . .venv/bin/activate && cd speech_to_text && python run_cli.py'
```

It asks which microphone to use:

```
[NPU] NPU userspace max frequency applied
List of Audio input devices:
  0 klamath-asoc: - (plughw:0,0), ALSA (128 in, 128 out)
  1 klamath-asoc: - (plughw:0,1), ALSA (128 in, 128 out)
  2 klamath-asoc: - (plughw:0,2), ALSA (128 in, 0 out)
  3 sysdefault, ALSA (128 in, 128 out)
* 4 default, ALSA (128 in, 128 out)
  5 dmix, ALSA (0 in, 2 out)
Enter input device to listen on [default]:
```

Type `2`, the Sense mics. **Don't press Enter for `default`**: it hangs and
never returns audio. ([K4](../README.md#k4))

Then talk. Each pause ends a line:

```
Moonshine is running. Press Ctrl+C to quit.

This is a test.
To test the.
Coral board
I am testing the coral board right now can you understand what i'm saying
```

Press Ctrl-C to quit.

### Speak and translate

Walkthrough 1 typed into Gemma. Now speak to it: Moonshine hears you, Gemma
translates, both on the NPU.

**PC:**

```bash
adb shell -t 'cd /home/root/sl2610-examples && . .venv/bin/activate && cd gemma_translate && python run_cli.py'
```

Gemma takes about 30 seconds to load. Type `2` at the same device prompt, then
speak. Press a number key to switch language.

```
=== Astra SL2610 Voice Translation Engine ===
Press a listed number to change language:
  1: Spanish
  2: French
  3: German
  4: Portuguese
  5: Bahasa Indonesia
Speak to translate. Press Ctrl+C to exit.

[Ready] Listening...
[You] Where is the train station?  (296ms | RTF(audio)=0.17)
[Translation] "¿Dónde está el estación de tren?"  (TTFT=1046ms | 18.5 tok/s)

[Ready] Listening...

[Language changed to: French]
…
[You] But why?  (238ms | RTF(audio)=0.23)
[Translation] "Mais pourquoi ?"  (TTFT=912ms | 18.3 tok/s)

[Ready] Listening...
[You] Because the record player is broken.  (309ms | RTF(audio)=0.14)
[Translation] "Parce que le multimètre est cassé."  (TTFT=1091ms | 19.9 tok/s)
```

Speech to text takes about 300 ms. The first translated word comes about a
second later. The 270M model still slips: a record player became a
multimeter. Press Ctrl-C to quit.

A long translation can print several times over when it's wider than your
terminal. Widen the window to avoid it.

**PC:** when you're done, shut the board down before unplugging it:

```bash
adb shell poweroff
```

---

## I2C on this board

From both walkthroughs:

| Bus | Where | What's on it |
|---|---|---|
| `i2c-1` | mikroBUS (SM_TW1) | Power-management chip at 0x60 |
| `i2c-2` | Qwiic J8 (TW2), probably | Empty until you plug something in. Confirm with `i2cdetect -y -r 2`. |
| `i2c-3` | Camera / display | ov5647 at 0x36, an unidentified device at 0x0c; touch (0x38) and 7" panel (0x45) when a display is attached |
| none | 20-pin header I2C (SM_TW0) | Disabled in the stock device tree |
