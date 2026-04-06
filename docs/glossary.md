# AnyFloat Glossary

| Term             | Meaning                                                                                  | Code Reference                                                           |
|------------------|------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Floating Panel   | An always-on-top text window opened by the app.                                          | `FloatingPanelController`, `FloatingBorderlessPanel`, `FloatingTextView` |
| Dock Minimize    | The app's minimize flow that sends panels to the Dock and shows the minimized count.     | `AppDelegate`, `FloatingPanelController`                                 |
| Text Content     | The observable text model bound to a floating panel.                                     | `FloatingTextContent`                                                    |
| Panel Controller | The object that manages panel creation, layout, minimize/restore, and state.             | `FloatingPanelController`                                                |
| Panel State      | The current counts of visible, minimized-to-Dock, closed-history, and total panels.      | `PanelControllerState`                                                   |
