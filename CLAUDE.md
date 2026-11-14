# The Inheritance

## Game concept
Details: `/docs/The_Inheritance_Sim_Spec.md` (sim) and `/docs/The_Inheritance_Story_Bible.md` (story). Read both before building features.

Single-player space mission design game (NASA Space Apps 2026). In an alternate 1960s, the engineer behind the first crewed Moon landing dies after a fight with his kid. The kid joins NASA as a clerk and climbs to Flight Director over 6 levels (satellite, animal return, crewed orbit, docking, robotic landing, crewed Moon landing), learning who their father was from his tapes. Theme: you can't finish someone else's dream, only build your own. Toy-brick art style, 60s palette, warm humour; no NASA logos or real people.

The player freely designs rockets and spacecraft from parts. A real-physics sim (Tsiolkovsky, orbital mechanics, power, data, re-entry, live launch ascent) decides the outcome, with no scripted results. Failures trigger gentle cutscenes and a debrief using the player's own numbers. Three modes share one sim: Cadet (auto-calculated), Engineer (default; formulas shown), Flight Director (player enters their own calculations).

## Tech stack
- Godot 4 (project config targets 4.3), GDScript
- Renderer: GL Compatibility (required for Web export)
- Export target: Web (HTML5), preset "Web" -> `build/web/index.html`; threads disabled for easy hosting
- Display: 1920x1080 base viewport, `canvas_items` stretch, aspect `keep`

## Folder structure
```
/data                 JSON game data: parts, levels, dialogue, events
/docs                 Design docs (Sim Spec, Story Bible)
/scripts/sim          Pure GDScript physics/sim classes (no UI)
/scripts/systems      Autoloads and game systems (GameState, SceneManager)
/scenes/ui            UI scenes
/scenes/world         3D/2D world scenes
/scenes/cutscenes     Cutscene scenes
/assets/models        3D models
/assets/audio         Audio
/assets/ui            UI art
```
Entry point: `res://scenes/main.tscn` (script `scripts/main.gd`).

## Autoloads
- `GameState` (`scripts/systems/game_state.gd`): current level, unlocked parts, saved designs, budget, mode (`GameState.Mode.CADET/ENGINEER/FLIGHT_DIRECTOR`).
- `SceneManager` (`scripts/systems/scene_manager.gd`): `SceneManager.change_scene("res://...tscn")`. Main registers a container node; scenes are swapped inside it.
- `DataLoader` (`scripts/systems/data_loader.gd`): loads every JSON file in /data.
- `StoryTriggers` (`scripts/systems/story_triggers.gd`): `enter_area(id)` / `fire(event_id)`; world scenes report, story systems listen.

## Facility
Title -> `scenes/world/facility/facility.tscn` (rooms from `data/facility.json`). Rooms share one rocket through `DesignSession` (`scripts/systems/design_session.gd`), which writes to `GameState`. F1 opens the RocketBuilder sheet as a debug/fallback view. Headless check: `-- --selftest` on the facility scene.

## Rules
1. All game data (parts, levels, dialogue, events) lives in JSON files under `/data`. Never hardcode it in scripts.
2. Physics/sim logic lives in pure GDScript classes under `/scripts/sim` with no UI code (no Control/scene-tree dependencies), so it stays testable.
3. UI lives under `/scenes/ui`.
4. Every AI-written file starts with the comment: `# Code generated with AI assistance (Claude). Reviewed by team.`
5. Switch scenes only through `SceneManager`; shared state goes through `GameState`.
