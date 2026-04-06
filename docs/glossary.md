# AnyFloat Glossary

| Term             | Meaning                                                                                          | Code Reference                                                           |
|------------------|--------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Floating Panel   | An always-on-top text window opened by the app.                                                  | `FloatingPanelController`, `FloatingBorderlessPanel`, `FloatingTextView` |
| Dock Summary     | The Dock icon/badge state that reflects hidden and minimized panels waiting to be restored.      | `AppDelegate`, `FloatingPanelController`                                 |
| Text Content     | The observable text model bound to a floating panel.                                             | `FloatingTextContent`                                                    |
| Panel Controller | The object that manages panel creation, layout, hide/minimize, restore, and state.              | `FloatingPanelController`                                                |
| Panel State      | The current counts of visible, hidden, minimized-to-Dock, closed-history, and total panels.     | `PanelControllerState`                                                   |
