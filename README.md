# CinemaxX Diagnostics Suite

PowerShell-basierte Diagnose- und Überwachungssuite für CinemaxX-Workstations und -Server.

## Status

Aktuelle Entwicklungsphase: `2.0.0-alpha`

## Projektstruktur

```text
Config/      Konfigurationsdateien
Install/     Installations- und Setup-Skripte
Logs/        Laufzeitprotokolle (nicht versioniert)
Modules/     PowerShell-Module
Reports/     Generierte Berichte (nicht versioniert)
Snapshot/    Diagnosesnapshots (nicht versioniert)
Watcher/     Watcher- und Überwachungsskripte
```

## Start

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Start-CDS.ps1
```

## Voraussetzungen

- Windows PowerShell 5.1 oder PowerShell 7
- Leserechte für Windows-Ereignisprotokolle
- Für einzelne Diagnosefunktionen gegebenenfalls Administratorrechte

## Ziel

Die Suite soll wiederkehrende Fehler an Kassen, Druckern, USB-Geräten, Windows-Diensten und OPOS-Komponenten nachvollziehbar erfassen und für die spätere Analyse als Logs und Snapshots bereitstellen.
