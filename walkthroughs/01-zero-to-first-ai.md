# Walkthrough 1 — Zero to first AI

Take a bare Coralboard SL and a blank microSD card, get Linux booted, get the
board online through your PC's USB cable, and run two models on the NPU: an
image classifier, then Gemma 3 translating text.

Every command below is copy-pasteable, and every block of output is real. It
was captured from an actual bring-up on 2026-11-15, not transcribed by hand.
Long outputs are trimmed where marked with `…`.

**Time:** about 45 minutes, most of it writing the SD card.
**You need:**

- A Coralboard SL (the retail board, SL2619)
- A microSD card: 16 GB or larger, rated C10/U1/V10 and A1
- A USB microSD card reader
- A USB-C **data** cable
- A Linux PC with NetworkManager (tested on Ubuntu)

No camera, Wi-Fi module or Sense add-on yet. Those are
[walkthrough 2](02-full-kit.md).

---

## What you're about to do

The board has a single USB-C port, lower right. It carries both power and data,
so one cable to your PC does everything here. Over that cable the board
presents two things once Linux is up:

| What | Host side | Board side |
|---|---|---|
| ADB, for a shell and file copy | `adb shell` | — |
| A USB network link (NCM) | `enx<mac>` | `usb0` |

Two things catch almost everyone:

1. **No SD card, no board.** The Coralboard SL boots only from microSD. Without
   a flashed card it never shows up on USB at all, with no error anywhere.
2. **Your PC has to share its network.** The USB link comes up, but nothing on
   it hands out an address until you tell the host to.

---

## Step 1 — Download the SD card image

The tested image is Astra SDK **`scarthgap_6.12_v2.6.1`**, from the
[release page](https://github.com/synaptics-astra/sdk/releases/tag/scarthgap_6.12_v2.6.1).
Pick **SD card image for sl2619_coralboard_oobe_scarthgap**.

> **Google I/O edition boards:** this release does not support them. Those
> boards boot from eMMC and need [v2.5.0](https://github.com/synaptics-astra/sdk/releases/tag/scarthgap_6.12_v2.5.0).

```bash
mkdir -p ~/Downloads/coralboard_sl_v2.6.1 && cd ~/Downloads/coralboard_sl_v2.6.1
```

```bash
curl -fLO https://github.com/synaptics-astra/sdk/releases/download/scarthgap_6.12_v2.6.1/sl2619_coralboard_oobe_scarthgap_wic_6.12_v2.6.1.zip
```

```bash
unzip -l sl2619_coralboard_oobe_scarthgap_wic_6.12_v2.6.1.zip
```

```
Archive:  sl2619_coralboard_oobe_scarthgap_wic_6.12_v2.6.1.zip
  Length      Date    Time    Name
---------  ---------- -----   ----
15519990784  2026-10-12 21:37   astra-media-oobe-sl2619-coralboard.rootfs-20261013002345.wic
---------                     -------
15519990784                     1 file
```

The zip is 2 GB, but the image inside is **15.52 GB**. A "16 GB" card is about
15.9 GB, so it fits with roughly 0.4 GB to spare. If `dd` in the next step stops
with `No space left on device`, your card is too small.

---

## Step 2 — Write the card

Plug the reader in and find the card. **Writing to the wrong device erases it**,
so check the size and the `usb` transport:

```bash
lsblk -d -o NAME,SIZE,TRAN,RM,MODEL
```

```
NAME      SIZE TRAN   RM MODEL
sda      14.8G usb     1 STORAGE DEVICE
nvme0n1 953.9G nvme    0 SAMSUNG MZVL81T0HELB-00BH1
```

Here it's `/dev/sda`. Unmount it and write the image straight from the zip:

```bash
sudo umount /dev/sda1 && unzip -p ~/Downloads/coralboard_sl_v2.6.1/sl2619_coralboard_oobe_scarthgap_wic_6.12_v2.6.1.zip | sudo dd of=/dev/sda bs=4M status=progress conv=fsync
```

```
113246208 bytes (113 MB, 108 MiB) copied, 1.00016 s, 113 MB/s
…
4064280576 bytes (4.1 GB, 3.8 GiB) copied, 35.0185 s, 116 MB/s
…
9630121984 bytes (9.6 GB, 9.0 GiB) copied, 409.067 s, 24 MB/s
…
```

Don't trust the speed at the start. The first few GB land in your PC's memory,
then the rate drops to what the card can really write (about 13 MB/s on ours).
This run took about 30 minutes. It's finished when the prompt comes back, not
when the counter reaches 15.5 GB.

Check the partitions:

```bash
lsblk -o NAME,SIZE,PARTLABEL /dev/sda
```

```
NAME     SIZE PARTLABEL
sda     14.8G 
├─sda1    16M 
├─sda2     1M key_a
…
├─sda12  2.5G rootfs_a
├─sda13  2.5G rootfs_b
…
└─sda18  9.3G home
```

Eighteen partitions, with two copies of the system (`rootfs_a`, `rootfs_b`)
and a `home` partition where everything you install will live. The layout is
fixed in the image, so a bigger card doesn't give you a bigger `home`.

Power the reader off so the card is safe to pull:

```bash
udisksctl power-off -b /dev/sda
```

---

## Step 3 — Boot

1. With the board **unpowered**, push the card into the microSD slot.
2. Plug the board's USB-C into your PC.
3. Wait about 50 seconds.

The LEDs tell you where it is:

| LED | Meaning |
|---|---|
| Green | Power. On whenever the board has power. |
| Red, two short blinks then a pause | Heartbeat. Linux is running. |
| Blue | Storage activity. |

Green with no red heartbeat after a minute means it isn't booting: check the
card is flashed and was inserted before power-on.

---

## Step 4 — Connect with ADB

ADB isn't installed on Ubuntu by default. The package also installs the udev
rules, so there's nothing else to configure:

```bash
sudo apt install adb
```

```bash
adb devices -l
```

```
List of devices attached
sl2619-coralboard      device usb:1-11.1.2 transport_id:1
```

```bash
adb shell cat /etc/astra_version
```

```
scarthgap_6.12_v2.6.1
```

You're in as `root` with no password. `adb shell` on its own gives you an
interactive shell.

---

## Step 5 — Get the board online

The quick way is the helper in this repo, which does the three steps below:

```bash
scripts/share-usb-network.sh
```

<!-- TODO: capture the script's own output on the next bring-up and paste it here. -->

Here's what it does, and what each part looks like.

**On the PC:** the board's link shows up but never gets an address:

```bash
nmcli -t dev status | grep enx
```

```
enx5a176425fae1:ethernet:connecting (getting IP configuration):Wired connection 1
```

Tell NetworkManager to share your connection on it. This only affects the live
link and is undone when the board disconnects:

```bash
nmcli device modify enx5a176425fae1 ipv4.method shared ipv6.method ignore
```

```
Connection successfully reapplied to device 'enx5a176425fae1'.
```

Your interface name will be different: use the `enx…` name from the previous
command. The PC is now `10.42.0.1` on that link, handing out addresses.

**On the board:** ask for one:

```bash
adb shell udhcpc -i usb0 -n -q
```

```
udhcpc: lease of 10.42.0.28 obtained from 10.42.0.1, lease time 3600
/etc/udhcpc.d/50default: Adding DNS 10.42.0.1
```

**Fix the clock.** The board has no battery-backed clock. Ours booted thinking
it was January 2025, and that breaks every HTTPS download:

```bash
adb shell date
```

```
Wed Jan  8 18:24:27 UTC 2025
```

```
fatal: unable to access 'https://github.com/synaptics-astra-demos/sl2610-examples/': SSL certificate problem: certificate is not yet valid
```

Time sync is running but gave up before the network existed. Restart it:

```bash
adb shell systemctl restart systemd-timesyncd
```

```bash
adb shell date
```

```
Sun Nov 15 19:34:04 UTC 2026
```

---

## Step 6 — Look around

```bash
adb shell
```

```bash
uname -a && python3 --version && df -h / /home
```

```
Linux sl2619-coralboard 6.12.62 #1 SMP PREEMPT Mon Oct 12 20:27:00 UTC 2026 aarch64 GNU/Linux
Python 3.12.9
Filesystem                Size      Used Available Use% Mounted on
/dev/mmcblk2p12           2.3G      2.1G     33.7M  98% /
/dev/mmcblk2p18           9.0G    183.5M      8.3G   2% /home
```

This is Yocto Linux, not Ubuntu: there's no `apt`, and many commands are the
smaller BusyBox versions (`head -n 8`, not `head -8`; no `timeout`).

Look at `/`: **98% full out of the box, 33 MB free.** Everything you add has to
go in `/home/root`, which has 8 GB free.

---

## Step 7 — Get the examples

Still in the board's shell:

```bash
cd /home/root
```

```bash
git clone --recurse-submodules https://github.com/synaptics-astra-demos/sl2610-examples
```

```
…
Submodule path 'app_utils/torq_examples': checked out 'f99b49136fa67d73e81bbc724999f78f5fe96599'
```

This walkthrough was tested at commit `b3882df`, the head of `main` on
2026-11-15. If upstream has moved on and something below doesn't match, pin to
that commit:

```bash
cd sl2610-examples && git checkout b3882df && git submodule update --init --recursive
```

Make a Python environment and install the shared dependencies:

```bash
python3 -m venv .venv --system-site-packages
```

```bash
source .venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt
```

```
…
Successfully installed Pillow-13.0.0 certifi-2026.10.23 charset_normalizer-3.5.2 filelock-4.2.10 fsspec-2026.9.0 hf_xet-1.8.0 huggingface_hub-0.31.4 idna-3.20 ml_dtypes-0.6.0 packaging-26.3 pyyaml-6.0.3 requests-2.33.1 torq-runtime-2.3.1 tqdm-4.67.3 typing-extensions-4.16.0 urllib3-2.8.0
```

---

## Step 8 — Hello world: classify an image

MobileNetV2, compiled for the NPU. No camera needed: it reads a sample image.

```bash
cd image_classification && pip install -r requirements.txt && python setup_demo.py
```

```
[INFO    ] image_classification.setup: Resolving MobileNetV2 models: [v2]
[INFO    ] image_classification.setup: MobileNetV2 model files ready at '/home/root/sl2610-examples/models/Synaptics/mobilenet_v2-int8-torq'
```

```bash
python3 run_cli.py --image ../samples/cat.jpg
```

```
[NPU] NPU userspace max frequency applied

[1/4] Preprocessing image...

[2/4] Running model on board...
Time: 8.205ms

[3/4] Processing output...
Warning: Output shape (1, 1000) doesn't match expected (1, 10000). Metadata might be needed.

[4/4] Classification Results:
  1. Persian cat : 0.433594
  2. Angora, Angora rabbit : 0.171875
  3. lynx, catamount : 0.046875
  4. tabby, tabby cat : 0.031250
  5. Egyptian cat : 0.019531

Top Prediction: Persian cat

[5/5] Saving result image...
Resized image to 800x480 (letterboxed) for display.
Loaded font: /usr/share/fonts/ttf/LiberationSans-Regular.ttf
Result image saved to: output_classification.jpg
Display not requested. Use --display to show the image.
[NPU] NPU userspace min frequency applied
[torq] Skipping binding ranges in XRAM footprint for dmabuf mode
```

The `Output shape` warning is expected: it's in the example's own README too.

Copy the annotated image back to your PC (in a second terminal on the PC):

```bash
adb pull /home/root/sl2610-examples/image_classification/output_classification.jpg
```

![MobileNetV2 result on the sample cat image](images/01-cat-classified.jpg)

---

## Step 9 — Run Gemma 3 on the NPU

Gemma 3 270M is a small language model. The repo's demo uses it to translate.
It's built for speech, but `--text` lets you type instead, so no microphone is
needed.

The demo loads the audio libraries even in text mode, so install them first.
This writes about 9 MB to the nearly full `/`:

```bash
cd /home/root/sl2610-examples && ./setup/install_portaudio.sh
```

```
…
  OK: /usr/lib/libportaudio.so.19.8 (531360 bytes)
  OK: /usr/lib/libjack.so.0.1.0 (2309192 bytes)
Done.
```

```bash
cd gemma_translate && pip install -r requirements.txt && python setup_demo.py
```

```
…
[INFO    ] utils.model_setup: gemma3 model files for version v2.3.0 ready at '/home/root/sl2610-examples/models/Synaptics/gemma-3-270-GPTQ-int4-it-torq'
```

```bash
python run_cli.py --text
```

```
…
[INFO    ] gemma_translate.translation: Translation service ready (backend=GemmaTorq)
[NPU] NPU userspace max frequency applied

=== Astra SL2610 Voice Translation Engine ===
Type a phrase and press Enter to translate.
Use /1-/6 to switch language, /q to quit:
  /1: Spanish
  /2: French
  /3: German
  /4: Portuguese
  /5: Bahasa Indonesia

→ [You] Hello, where is the train station?
[Translation] "Hola, ¿puedes decirme dónde está el estación de tren?"  (TTFT=1046ms | 19.4 tok/s)
```

The translation streams in word by word. It's a 270M-parameter model, so expect
the odd mistake (it should be *la* estación). Type `/q` to quit.

---

## Step 10 — Shut down

Don't just pull the cable: the SD card may still have writes pending.

```bash
adb shell poweroff
```

Unplug once the red heartbeat stops.

---

## If something's wrong

| You see | It means |
|---|---|
| Nothing in `lsblk`/`adb devices`, no USB events at all | No bootable card. Flash one and insert it before power-on. |
| Green LED only, no red heartbeat | The board isn't booting: reflash the card. |
| `enx…` stuck on "getting IP configuration" | The host isn't sharing. Run Step 5. |
| `certificate is not yet valid` | The board's clock is wrong. Restart `systemd-timesyncd`. |
| `No space left on device` on the board | You wrote outside `/home/root`. `/` has almost no room. |
| `No space left on device` while flashing | The card is smaller than the 15.52 GB image. |
