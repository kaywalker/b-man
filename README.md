# B-Man

Bomberman-Klon in Godot 4.7, angelehnt an den Battle-Modus von **Super Bomberman (SNES, 1993)**.
Gebaut für unser Gaming-Tablet: 16:9-Bildschirm, 4 Spieler mit je einem Joystick und zwei Buttons,
Raspberry Pi.

Grafik und Sound werden komplett im Code erzeugt. Es gibt keine Asset-Dateien.

## Spielen

| Eingabe      | Lobby                        | Im Spiel                               |
|--------------|------------------------------|----------------------------------------|
| Joystick     | Einstellungen wählen/ändern  | laufen (diagonal = um die Ecke biegen) |
| **A**        | mitmachen, dann bereit       | Bombe legen                            |
| **B**        | zurück / abmelden            | Fernzünder: älteste eigene Bombe zünden |
| Esc          | Programm beenden             | zurück zur Lobby                       |
| F11          | Vollbild an/aus              | Vollbild an/aus                        |

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

Beim ersten Start legt das Spiel `controls.cfg` im Benutzerordner an:

```
~/.local/share/godot/app_userdata/B-Man/controls.cfg
```

Pro Spieler (`[player1]` … `[player4]`) lässt sich dort einstellen:

- `joypad_device`: Geräte-Index des Controllers (Standard: 0–3 in Anschlussreihenfolge)
- `axis_x` / `axis_y`: Achsen des Joysticks (Standard 0/1). D-Pad- und Hat-Eingaben werden zusätzlich immer ausgewertet.
- `button_a` / `button_b`: Button-Nummern (Standard 0/1)
- `key_*`: Tastatur-Fallback (P1 WASD+Q/E, P2 Pfeile+Enter/Backspace, P3 IJKL+U/O, P4 Numpad 8456+7/9)

`[general] deadzone` regelt, ab welchem Ausschlag der Joystick zählt.

Die Lobby zeigt unten rechts an, wie viele Controller erkannt sind. Zum Testen der Belegung
einfach in der Lobby A drücken: die passende Spielerfigur meldet sich an.

> Falls die Arcade-Encoder sich als **Tastatur** statt als Controller melden (manche I-PAC-Boards tun das),
> trägt man die gesendeten Tasten unter `key_*` ein.

## Auf dem Raspberry Pi starten

Das Projekt nutzt den **Compatibility-Renderer** (OpenGL ES 3 / OpenGL 3.3) und rendert intern mit
480×270 Pixeln, die auf den Bildschirm hochskaliert werden. Damit ist die GPU-Last minimal.

**Variante A: direkt aus dem Projektordner**

1. Godot 4.7 für Linux **arm64** von <https://godotengine.org/download/linux/> laden.
2. Starten mit `./Godot_v4.7.x-stable_linux.arm64 --path /pfad/zu/b-man`

**Variante B: Export als eigenständige Datei**

1. Am PC in Godot 4.7 die Export-Templates installieren (*Editor → Export-Templates verwalten*).
2. *Projekt → Exportieren →* Preset **„Raspberry Pi (Linux arm64)“** → `build/b-man.arm64`
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
