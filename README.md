<p align="center">
AnyFloat is a native macOS app that captures text<br/>
into always-on-top floating windows.
</p>

<p align="center">
<a href="https://github.com/fytriht/anyfloat/releases">Download from Releases</a>
<!-- [Download from Releases](https://github.com/fytriht/anyfloat/releases) -->
</p>

<hr/>

<table>
  <tr>
    <td>
      <img src="docs/assets/2602241.gif" width="300">
    </td>
    <td>
      <img src="docs/assets/2602262.gif" width="300">
    </td>
    <td><img src="docs/assets/2602262.gif" width="300"></td>
  </tr>
  <tr>
  <td>Trigger the hotkey to capture selected text</td>
  <td>Supports multiple floating windows</td>
  <td>With no selection, the hotkey opens a blank quick-note panel</td>
  </tr>
</table>

## Why AnyFloat?

1. Quickly capture snippets for later reference without frequent context switching.
2. When juggling multiple parallel tasks, open a blank window to jot down ideas instantly.
3. Unlike Apple Notes, it is super lightweight and keeps a persistent floating window within reach.

## Quick Start

1. Download from [Releases](https://github.com/fytriht/anyfloat/releases).
2. Launch AnyFloat.
3. Select text in any app.
4. Press `Shift + Option + F`
5. Done.
   
> You can always find AnyFloat later in the menu bar.
> 
> <img src="docs/assets/2602261.png" width="160px"/>

## FAQ

- Why does AnyFloat need Accessibility permission?
  - To capture selected text across apps. macOS requires this for cross-app UI access and the `Cmd + C` compatibility fallback.
  - Without it, floating windows still work, but text capture may fail.
- Hotkey does not trigger:
  - Check shortcut conflicts with other tools.
  - Relaunch AnyFloat.
- Selected text is not captured in some apps:
  - Confirm Accessibility permission is enabled for `AnyFloat`.
  - If you just granted permission, relaunch AnyFloat once.

## Contributing

For developing and contributing workflow, see [`CONTRIBUTING.md`](CONTRIBUTING.md).
