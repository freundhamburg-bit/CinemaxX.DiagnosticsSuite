# Changelog

Alle wesentlichen Änderungen an der CinemaxX Diagnostics Suite werden in dieser Datei dokumentiert.

## [2.1.0-alpha] - 2026-07-30

### Hinzugefügt

- automatische Erkennung der Profile Laptop, POS und Server
- profilabhängige Auswahl der zu prüfenden Windows-Dienste
- manuelle Profilvorgabe über den Parameter `-Profile`

### Behoben

- PrinterDiagnostics funktioniert auch bei genau einem gefundenen Drucker
- leere Ereignisabfragen werden nicht mehr als Fehlerereignis protokolliert
- Logdateien werden mit UTF-8-BOM angelegt, damit Umlaute in Windows PowerShell korrekt dargestellt werden

## [2.0.0-alpha] - 2026-07-29

### Hinzugefügt

- zentrale JSON-Konfiguration
- ConfigManager-Modul mit Validierung und Reload
- Logger mit Log-Leveln, täglicher Datei und Aufbewahrung
- ServiceWatcher für Windows-Dienste
- EventWatcher für Windows-Ereignisprotokolle
- SnapshotManager für System-, Drucker-, USB- und Dienstdaten
- Startskript für Einzel- und Dauerbetrieb
- Installationsskript mit optionaler geplanten Aufgabe
