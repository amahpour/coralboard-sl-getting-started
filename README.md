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

Walkthrough 1 covers each of these where you'll hit it.

## License

[MIT](LICENSE.md). The Synaptics examples and SDK images are under their own
licenses.
