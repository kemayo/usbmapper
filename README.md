# USB Mapper

Native macOS app that visualises USB device topology, highlighting connections
where devices are running slower than their maximum.

## Features

- Left-to-right chart of every USB bus, hub, and device
- Colour-coded connection speeds (USB 1.x / 2.0 / 3.x / Thunderbolt)
- Bottleneck detection:
  - **Hub-limited**: a USB 3.x–capable device running at USB 2.0 speeds, traced to the topmost USB 2.x hub in the chain
  - **Speed mismatch**: a hub negotiating a lower speed than its parent, highlighted in red on the connecting edge
- Inspector panel (⌘⌥I) with speed, power, and identifier details for any selected device or bus
- Power budget display: bus draw vs. available for each hub
- Bottleneck summary bar with one-click navigation to affected devices

## Usage

The app reads your USB topology at launch and on each press of the Refresh
button. Select any device or bus header to view details in the inspector on
the right.

## How it works

USB Mapper shells out to [`cyme`](https://github.com/tuna-f1sh/cyme) (bundled)
to get a view of the USB topology. Bottleneck detection compares each
device's declared USB version against its negotiated link speed.
