# omarchy-gsm-status

An [Omarchy](https://omarchy.org/) shell bar widget for mobile broadband
(GSM) modems. Shows signal strength, network generation (2G/3G/4G/5G),
upload rate, and a connect/disconnect toggle.

Omarchy's stock network panel doesn't support GSM at all — there's no
`Quickshell.Networking` device type for it, so this widget polls `nmcli` and
`mmcli` directly. The bar icon hides itself entirely when no modem is
present, so it's safe to install even on a machine without one.

## Install

```
omarchy plugin add https://github.com/Thomster/omarchy-gsm-status.git
```

## Requirements

- NetworkManager (`nmcli`)
- ModemManager (`mmcli`) — needed for signal quality, access technology, and
  the modem's network interface (for the upload-rate reading)

## Related

Pairs well with [omarchy-network-priority](https://github.com/Thomster/omarchy-network-priority)
(auto-disables GSM/Wi-Fi whenever Ethernet is connected), but neither
depends on the other — this widget works standalone.

## How this came to be

This is a personal customization for my own Omarchy setup, built with the
help of [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding
agent). I use it daily on my own machine, but I'm not a professional plugin
developer — please read through the source before installing, especially
anything that touches system or network state, and open an issue if
something looks off.

## License

MIT
