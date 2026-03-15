# AnyFloat Glossary

| Term             | Meaning                                                                           | Code Reference                                                           |
|------------------|-----------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Floating Panel   | An always-on-top text window opened by the app.                                   | `FloatingPanelController`, `FloatingBorderlessPanel`, `FloatingTextView` |
| Stash Widget     | A small floating widget shown when panels are stashed; clicking it restores them. | `StashWidgetController`, `StashWidgetView`                               |
| Text Content     | The observable text model bound to a floating panel.                              | `FloatingTextContent`                                                    |
| Panel Controller | The object that manages panel creation, layout, stash, restore, and state.        | `FloatingPanelController`                                                |
| Panel State      | The current counts of visible, stashed, closed-history, and total panels.         | `PanelControllerState`                                                   |
