class_name Defs
## Globale Konstanten: Spielfeld, Timing, Farben, Items.

const TILE := 16
const GRID_W := 15
const GRID_H := 13
const SCREEN := Vector2(480, 270)
## Linke obere Ecke des Spielfelds in Bildschirmpixeln (zentriert, Seitenleisten links/rechts).
const ARENA_ORIGIN := Vector2(120, 40)

const MAX_PLAYERS := 4
const PLAYER_NAMES := ["P1", "P2", "P3", "P4"]
## Farben wie bei Super Bomberman: Weiß, Schwarz, Rot, Blau.
const PLAYER_COLORS := [Color("f4f4f4"), Color("3a3a48"), Color("e04040"), Color("4070e8")]
const PLAYER_SUITS := [Color("5878f0"), Color("b03838"), Color("f0f0f0"), Color("f0d040")]
## Start: P1 oben links, P2 oben rechts, P3 unten links, P4 unten rechts.
const START_CELLS := [Vector2i(1, 1), Vector2i(13, 1), Vector2i(1, 11), Vector2i(13, 11)]

const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

enum Cell { EMPTY, HARD, SOFT }
enum Item { BOMB, FIRE, SPEED, KICK, REMOTE, FULL_FIRE, SKULL }
enum Disease { NONE, SLOW, FAST, REVERSE, NO_BOMB, AUTO_BOMB, SHORT_FIRE }

## Wie viele Items unter den Softblöcken versteckt werden.
const ITEM_POOL := {
	Item.BOMB: 10,
	Item.FIRE: 10,
	Item.SPEED: 6,
	Item.KICK: 3,
	Item.REMOTE: 2,
	Item.FULL_FIRE: 1,
	Item.SKULL: 3,
}
## Wahrscheinlichkeit, dass ein freies Feld einen Softblock bekommt.
const SOFT_BLOCK_CHANCE := 0.8

const BASE_SPEED := 3.2        # Felder pro Sekunde
const SPEED_STEP := 0.55
const MAX_SPEED_LVL := 6
const MAX_BOMBS := 8
const MAX_FIRE := 8
const FULL_FIRE := 12
const START_FIRE := 2

const FUSE_TIME := 2.5
const FLAME_TIME := 0.6
const BURN_TIME := 0.6
const BOMB_SLIDE_SPEED := 9.0
const DISEASE_TIME := 15.0
const DEATH_TIME := 1.2

const HURRY_AT := 60.0         # Sekunden Restzeit, ab der die Druckblöcke fallen
const PRESSURE_INTERVAL := 0.32
const FALL_TIME := 0.25

const COUNTDOWN_TIME := 2.2
const ROUND_SETTLE_TIME := 1.6
const ROUND_RESULT_TIME := 3.5
const MATCH_RESULT_TIME := 6.0


static func cell_to_screen(cell: Vector2) -> Vector2:
	## Mittelpunkt einer (ggf. gebrochenen) Feldkoordinate in Bildschirmpixeln.
	return ARENA_ORIGIN + (cell + Vector2(0.5, 0.5)) * TILE
