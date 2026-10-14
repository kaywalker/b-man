# B-Man

Bomberman-Klon in Godot 4.7, angelehnt an den Battle-Modus von **Super Bomberman (SNES, 1993)**.
Gebaut für unser Gaming-Tablet: 16:9-Bildschirm, 4 Spieler mit je einem Joystick und zwei Buttons,
Raspberry Pi.

Grafik und Sound werden komplett im Code erzeugt. Es gibt keine Asset-Dateien.

## Spielen

Gespielt wird am flach liegenden Bildschirm, jeder an einer Seite.

| Spieler | Figur   | Platz  | Startecke    | Gamepad | Tastatur (zum Testen)                   |
|---------|---------|--------|--------------|---------|-----------------------------------------|
| P1      | Weiß    | unten  | unten links  | Pad 1   | WASD · A = Shift · B = Strg             |
| P2      | Schwarz | rechts | unten rechts | Pad 0   | Pfeiltasten · A = Enter · B = ⌫         |
| P3      | Rot     | oben   | oben rechts  | Pad 2   | IJKL · A = U · B = O                    |
| P4      | Blau    | links  | oben links   | Pad 3   | Ziffernblock 8456 · A = 0 · B = Enter   |

Die Pad-Zuordnung entspricht dem Büro-Tisch (die ersten beiden Controller sind dort andersherum
verkabelt), genau wie beim [Office Racer](https://github.com/knusperpixel/office-racer).

- **Joystick:** Der Stick ist pro Platz gedreht: „vom Spieler weg“ läuft die Figur immer vom eigenen Bildschirmrand weg. Die Tastatur ist nicht gedreht. Mit `-- --desktop` gelten für alle die normalen Bildschirmrichtungen.
- **B** = Gamepad-Knopf 1 (oder linke Schultertaste/Trigger): in der Lobby zurück, im Spiel Fernzünder.
- **A** = jeder andere Knopf. Der Prototyp meldet seinen Knopf als Knopf 3. In der Lobby mitmachen, dann bereit; im Spiel Bombe legen.
- **Esc** beendet in der Lobby das Programm und bricht im Spiel das Match ab. **F11** schaltet das Vollbild um.

Jeder Gamepad-Knopf wird in der Konsole ausgegeben (`Gamepad 0: Knopf 3`) und unten rechts in der Lobby angezeigt.

Sobald mindestens 2 Spieler beigetreten und alle bereit sind, startet das Match nach 3 Sekunden.
Wer zuerst die eingestellte Zahl an Runden gewinnt (1–5), gewinnt das Match.

### Regeln (wie im Original-Battle-Modus)

- Arena 15×13 mit festen Säulen und zufälligen Softblöcken. Die Startecken bleiben frei.
- Bomben explodieren nach 2,5 s als Kreuz. Flammen stoppen an Blöcken, zünden andere Bomben (Kettenreaktion) und zerstören Items.
- Unter Softblöcken liegen Items:
  - **Bombe**: +1 gleichzeitige Bombe
  - **Feuer**: +1 Reichweite
  - **Rollschuh**: schneller
  - **Stiefel (Kick)**: gegen eine Bombe laufen kickt sie weg
  - **Fernzünder**: Bomben explodieren erst auf Knopfdruck (B)
  - **Volles Feuer**: maximale Reichweite
  - **Totenkopf**: zufällige Krankheit für 15 s (langsam, rasend schnell, Steuerung vertauscht, keine Bomben, Dauer-Bomben, Mini-Flamme). Steckt andere bei Berührung an.
- Bei 1:00 Restzeit kommt **HURRY UP!**: Druckblöcke fallen spiralförmig von außen nach innen.
- Wer zuletzt übrig bleibt, gewinnt die Runde. Sterben alle gleichzeitig oder läuft die Zeit ab, ist die Runde unentschieden.

## Steuerung anpassen

Beim ersten Start legt das Spiel `controls.cfg` im Benutzerordner an
(`~/.local/share/godot/app_userdata/B-Man/controls.cfg`, auf dem Mac
`~/Library/Application Support/Godot/app_userdata/B-Man/`). Dort lassen sich ändern:

- `[general]`: `deadzone`, `table_mode` (Stick pro Platz drehen), `buttons_b` (Knöpfe für B, alle anderen sind A)
- `[player1]` … `[player4]`: `joypad_device`, `seat` (`unten`/`rechts`/`oben`/`links`) und die `key_*`-Tasten

Die Pad-Zuordnung geht auch per Startoption: `-- --pads=1,0,2,3` (Reihenfolge P1–P4, Zahl = Gamepad-Nummer ab 0).

## Builds (GitHub Actions)

Bei jedem Push baut `.github/workflows/build.yml` das Spiel: Godot 4.7.2 laden, Unit-Tests,
zwei Minuten Bot-Match als Smoke-Test, dann Export.

- **Fertige Builds:** GitHub → *Actions* → neuester Lauf → *Artifacts* → `B-Man`
  - `B-Man-raspberrypi-arm64.zip` – für den Pi
  - `B-Man-macos.zip` – für den Mac (Apple Silicon und Intel, ad-hoc signiert: beim ersten Start `xattr -cr B-Man.app` oder *Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen*)
- **Release:** Ein Tag `v*` (z. B. `git tag v0.2 && git push --tags`) legt die Builds zusätzlich als Release auf GitHub ab.

Lokal dasselbe prüfen:

```sh
godot --headless --path . -s tests/unit_test.gd               # Unit-Tests (Knöpfe, Stick-Drehung, Startfelder)
godot --headless --path . --fixed-fps 60 -- --autotest=120    # 2 Minuten Bot-Match
```

## Auf dem Raspberry Pi starten

Das Projekt nutzt den **Compatibility-Renderer** (OpenGL ES 3 / OpenGL 3.3) und rendert intern mit
480×270 Pixeln, die auf den Bildschirm hochskaliert werden. Damit ist die GPU-Last minimal.

**Variante A: direkt aus dem Projektordner**

1. Godot 4.7 für Linux **arm64** von <https://godotengine.org/download/linux/> laden.
2. Starten mit `./Godot_v4.7.x-stable_linux.arm64 --path /pfad/zu/b-man`

**Variante B: Export als eigenständige Datei**

1. Am PC in Godot 4.7 die Export-Templates installieren (*Editor → Export-Templates verwalten*).
2. *Projekt → Exportieren →* Preset **„Raspberry Pi (Linux arm64)“** → `build/linux-arm64/b-man.arm64`
3. Datei auf den Pi kopieren, `chmod +x b-man.arm64`, starten.

Das Spiel startet im Vollbild. Mit `-- --windowed` startet es im Fenster.

Für den Autostart reicht unter Raspberry Pi OS z. B. ein Eintrag in `~/.config/autostart/b-man.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=B-Man
Exec=/home/pi/b-man.arm64
```

## Projektstruktur

```
project.godot        Projekteinstellungen (480×270, Compatibility-Renderer)
scenes/main.tscn     Einstiegsszene
scripts/main.gd      Wechsel zwischen Lobby und Match
scripts/lobby.gd     Titelbildschirm, Anmeldung, Einstellungen
scripts/game.gd      Spiellogik: Arena, Bewegung, Bomben, Flammen, Items, Runden
scripts/player.gd    Spielerzustand und -darstellung
scripts/hud.gd       Seitenleisten, Timer, Einblendungen
scripts/art.gd       alle Zeichenroutinen (Pixel-Grafik im Code)
scripts/sfx.gd       prozedural erzeugte Soundeffekte (Autoload „Sfx“)
scripts/controls.gd  Input-Belegung und controls.cfg
scripts/defs.gd      Konstanten (Tempo, Zeiten, Item-Verteilung …)
```

Spielwerte wie Bombenzünder, Lauftempo oder Item-Anzahl stehen gesammelt in `scripts/defs.gd`.
