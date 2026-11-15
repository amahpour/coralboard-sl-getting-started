# Coralboard SL: Getting Started

A hands-on guide to the Synaptics Coralboard SL (Astra SL2619, Torq NPU built on
Google's Coral NPU), from a bare board to AI models running on the NPU.

The board ships on its own; the camera, Wi-Fi module and Sense add-on are sold
separately, and no single guide puts them together. These walkthroughs do, with
every command and its real output, including the parts that trip people up.

**[Start with walkthrough 1 →](walkthroughs/01-zero-to-first-ai.md)**

## What's here

| Path | What it is |
|---|---|
| [`walkthroughs/`](walkthroughs/README.md) | Step-by-step tutorials with captured output |
| [`scripts/share-usb-network.sh`](scripts/share-usb-network.sh) | One command to get the board online through your Linux PC's USB link |

## Tested with

| | Version |
|---|---|
| Board | Coralboard SL (retail, boots from microSD) |
| Astra SDK image | [`scarthgap_6.12_v2.6.1`](https://github.com/synaptics-astra/sdk/releases/tag/scarthgap_6.12_v2.6.1) |
| Examples | [`synaptics-astra-demos/sl2610-examples`](https://github.com/synaptics-astra-demos/sl2610-examples) at `b3882df` |
| Torq runtime | 2.3.1 (installed by pip) |
| Host | Ubuntu with NetworkManager |

The example applications themselves live in Synaptics' repository. This one
doesn't copy them: the walkthroughs clone it on the board.

## Things that will catch you out

- **The board doesn't boot without a microSD card**, and gives no sign of it on
  USB at all.
- **The board's root filesystem is 98% full out of the box.** Work in
  `/home/root`.
- **The board's clock is wrong after boot**, which breaks HTTPS until time sync
  is restarted.
- **USB networking needs your PC to share its connection**; the board can't get
  an address on its own.

The walkthroughs cover each of these where you'll hit it.

## Known issues

Problems found while writing the walkthroughs, where each one lives, and
whether Synaptics knows. "SDK image" means the Astra SDK Linux image; its
[repository](https://github.com/synaptics-astra/sdk) has issues turned off, so
those can only be reported through the
[Astra Support Portal](https://synacsm.atlassian.net/servicedesk/customer/portal/543).

| # | Problem | Lives in | Workaround | Reported |
|---|---|---|---|---|
| <a id="k1"></a>K1 | USB networking from a Linux PC isn't documented; the link never gets an address | Docs (examples README, Synaptics user guide) | [`scripts/share-usb-network.sh`](scripts/share-usb-network.sh) | [#13](https://github.com/synaptics-astra-demos/sl2610-examples/issues/13), fix proposed in [PR #14](https://github.com/synaptics-astra-demos/sl2610-examples/pull/14) |
| <a id="k2"></a>K2 | Board boots with a stale clock; HTTPS fails with `certificate is not yet valid` | SDK image | `systemctl restart systemd-timesyncd` once online (the script does it) | Mentioned in [#13](https://github.com/synaptics-astra-demos/sl2610-examples/issues/13), docs in [PR #14](https://github.com/synaptics-astra-demos/sl2610-examples/pull/14). Support portal: not yet. |
| <a id="k3"></a>K3 | `/` is 98% full out of the box (33 MB free) | SDK image | Keep everything in `/home/root` | Mentioned in [#13](https://github.com/synaptics-astra-demos/sl2610-examples/issues/13), docs in [PR #14](https://github.com/synaptics-astra-demos/sl2610-examples/pull/14). Support portal: not yet. |
| <a id="k4"></a>K4 | Voice demos: the `default` audio input hangs with the Sense add-on's mics | Examples (demo READMEs), possibly the image's ALSA config | Pick the `klamath-asoc … (hw:0,2)` input | [#15](https://github.com/synaptics-astra-demos/sl2610-examples/issues/15) |
| <a id="k5"></a>K5 | `--rotate 180` in the Sensor HAT camera command turns the picture upside down | Examples (object_detection, face_id READMEs) | Leave `--rotate` off | [#15](https://github.com/synaptics-astra-demos/sl2610-examples/issues/15) |
| <a id="k6"></a>K6 | The 20-pin header's I2C (SM_TW0) is disabled in the device tree | SDK image | Device-tree overlay | Not reported; may be intentional |
| <a id="k7"></a>K7 | `root` has no password, so SSH over Wi-Fi is open to your network | SDK image | `passwd` on the board | Not reported; usual for dev images |

## License

[MIT](LICENSE.md). The Synaptics examples and SDK images are under their own
licenses.
