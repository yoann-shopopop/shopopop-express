class_name GameConfig
extends RefCounted
## Shared tuning constants for the board's 3D presentation and interaction.
## Logic code (HexUtils/Board) stays unit-agnostic; only the view/interaction layers read these.

## Hexagon circumradius (center to corner), in world units.
const HEX_SIZE: float = 1.0
## Thickness of a placed tile — gives the "board piece" relief under the top-down light.
const TILE_HEIGHT: float = 0.25
## How far (in cells) the faint background lattice extends around the origin.
const GRID_RADIUS: int = 14

## Tint of the placement ghost when the move is legal / illegal.
const GHOST_VALID: Color = Color(0.35, 1.0, 0.45, 0.55)
const GHOST_INVALID: Color = Color(1.0, 0.35, 0.35, 0.55)
## Faint color of the empty background lattice tiles.
const LATTICE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.06)
