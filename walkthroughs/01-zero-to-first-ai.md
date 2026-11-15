# Walkthrough 1 — Zero to first AI

Take a bare Coralboard SL and a blank microSD card, boot Linux, and get the
board online through your PC's USB cable. Then run two models on the NPU: an
image classifier, and Gemma 3 translating text.

Every block of output is real, captured from a bring-up on 2026-11-15. Long
outputs are trimmed where marked with `…`. Each command says where it runs:
**PC** is your Linux machine, **board** is a shell on the Coralboard.

**Time:** about 45 minutes, most of it writing the SD card.
**You need:** a Coralboard SL (the retail board), a 16 GB or larger microSD
card rated C10/U1/V10 and A1, a USB microSD reader, a USB-C **data** cable, and
a Linux PC with NetworkManager.

---

## Step 1 — The board

The Coralboard SL is built around the Synaptics Astra SL2619: two Cortex-A55
cores at 2 GHz, a Cortex-M52 real-time core, a 1 TOPS NPU built on Google's
Coral NPU, and 2 GB of RAM.

Find two things on it:

- **The USB-C port, lower right.** It's the only one, and it carries both power
  and data. One cable to your PC does everything in this walkthrough.
- **The microSD slot.** The board boots only from microSD. With no card, it
  never shows up on USB at all.

---

## Step 2 — Flash the card

The tested image is Astra SDK `scarthgap_6.12_v2.6.1`. Google I/O edition
boards aren't supported by this release; they boot from eMMC and need
[v2.5.0](https://github.com/synaptics-astra/sdk/releases/tag/scarthgap_6.12_v2.5.0).

**PC:** download it.

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

The image inside is 15.52 GB. A 16 GB card holds about 15.9 GB, so it fits.

**PC:** plug in the card reader and find the card. Writing to the wrong device
erases it, so check the size and the `usb` transport:

```bash
lsblk -d -o NAME,SIZE,TRAN,RM,MODEL
```

```
NAME      SIZE TRAN   RM MODEL
sda      14.8G usb     1 STORAGE DEVICE
nvme0n1 953.9G nvme    0 SAMSUNG MZVL81T0HELB-00BH1
```

**PC:** here it's `/dev/sda`. Write the image straight from the zip:

```bash
sudo umount /dev/sda1 && unzip -p ~/Downloads/coralboard_sl_v2.6.1/sl2619_coralboard_oobe_scarthgap_wic_6.12_v2.6.1.zip | sudo dd of=/dev/sda bs=4M status=progress conv=fsync
```

```
113246208 bytes (113 MB, 108 MiB) copied, 1.00016 s, 113 MB/s
…
9630121984 bytes (9.6 GB, 9.0 GiB) copied, 409.067 s, 24 MB/s
…
```

The first few GB go to your PC's memory, then the speed drops to what the card
can write. Ours took about 30 minutes. It's done when the prompt comes back.

**PC:** check the partitions, then power the reader off:

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

```bash
udisksctl power-off -b /dev/sda
```

---

## Step 3 — First boot

1. With the board **unpowered**, push the card into the microSD slot.
2. Plug the board's USB-C into your PC.
3. Wait about 50 seconds. Green is power; a red double blink is the Linux
   heartbeat.

**PC:** install ADB and find the board:

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

**PC:** open a shell on it:

```bash
adb shell
```

**Board:** you're `root`, no password.

```bash
cat /etc/astra_version
```

```
scarthgap_6.12_v2.6.1
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

This is Yocto Linux (Poky 5.0.9, "scarthgap"), not Ubuntu. Many commands are
the smaller BusyBox versions. There is an `apt`, but it only sees Synaptics'
own package feed, and it installs to `/`, which is **98% full out of the box**.
Everything you add goes in `/home/root`. ([K3](../README.md#k3))

---

## Step 4 — Get it online

The USB cable also carries a network link: `usb0` on the board, `enx…` on the
PC. Nothing on it hands out an address yet. ([K1](../README.md#k1))

**PC:** the link is stuck:

```bash
nmcli -t dev status | grep enx
```

```
enx5a176425fae1:ethernet:connecting (getting IP configuration):Wired connection 1
```

**PC:** share your connection on it. Use your own `enx…` name. This lasts until
the board disconnects.

```bash
nmcli device modify enx5a176425fae1 ipv4.method shared ipv6.method ignore
```

```
Connection successfully reapplied to device 'enx5a176425fae1'.
```

**Board:** ask for an address:

```bash
udhcpc -i usb0 -n -q
```

```
udhcpc: lease of 10.42.0.28 obtained from 10.42.0.1, lease time 3600
/etc/udhcpc.d/50default: Adding DNS 10.42.0.1
```

Next time, one command on the PC does this step and the clock fix in Step 5:

```bash
scripts/share-usb-network.sh
```

---

## Step 5 — Hello world

**Board:** get Synaptics' examples:

```bash
cd /home/root
```

```bash
git clone --recurse-submodules https://github.com/synaptics-astra-demos/sl2610-examples
```

```
fatal: unable to access 'https://github.com/synaptics-astra-demos/sl2610-examples/': SSL certificate problem: certificate is not yet valid
```

The board has no battery-backed clock:

```bash
date
```

```
Wed Jan  8 18:24:27 UTC 2025
```

Time sync gave up before the network existed. Restart it
([K2](../README.md#k2)):

```bash
systemctl restart systemd-timesyncd
```

```bash
date
```

```
Sun Nov 15 19:34:04 UTC 2026
```

Now the clone works:

```bash
git clone --recurse-submodules https://github.com/synaptics-astra-demos/sl2610-examples
```

```
…
Submodule path 'app_utils/torq_examples': checked out 'f99b49136fa67d73e81bbc724999f78f5fe96599'
```

**Board:** make a Python environment:

```bash
cd sl2610-examples && python3 -m venv .venv --system-site-packages
```

```bash
source .venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt
```

```
…
Successfully installed Pillow-13.0.0 certifi-2026.10.23 charset_normalizer-3.5.2 filelock-4.2.10 fsspec-2026.9.0 hf_xet-1.8.0 huggingface_hub-0.31.4 idna-3.20 ml_dtypes-0.6.0 packaging-26.3 pyyaml-6.0.3 requests-2.33.1 torq-runtime-2.3.1 tqdm-4.67.3 typing-extensions-4.16.0 urllib3-2.8.0
```

**Board:** classify an image with MobileNetV2 on the NPU:

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
…
Result image saved to: output_classification.jpg
…
```

The `Output shape` warning is expected; the example's own README shows it too.

**PC:** in a second terminal, copy the result back:

```bash
adb pull /home/root/sl2610-examples/image_classification/output_classification.jpg
```

```
/home/root/sl2610-examples/image_classification/output_classification.jpg: 1 file pulled, 0 skipped. 15.2 MB/s (29273 bytes in 0.002s)
```

![MobileNetV2 result on the sample cat image](images/01-cat-classified.jpg)

---

## Step 6 — Gemma on the NPU

Gemma 3 270M is a small language model. Synaptics' demo uses it to translate.
It's built for speech, but `--text` lets you type instead.

**Board:** the demo loads audio libraries even in text mode:

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

The Spanish streams in word by word. It's a 270M model, so expect the odd slip:
it should be *la* estación. Type `/q` to quit.

**PC:** when you're done, shut the board down before unplugging it:

```bash
adb shell poweroff
```
