# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Story trigger hub (autoload "StoryTriggers"). World scenes report what the player
## does; story systems (tapes, cutscenes, event cards) listen. No content lives here.
##
##   StoryTriggers.enter_area("design_bay")   -> area_entered("design_bay", first_time)
##   StoryTriggers.fire("talked_to_dot")      -> event_fired("talked_to_dot", {})

signal area_entered(area_id: String, first_time: bool)
signal event_fired(event_id: String, payload: Dictionary)

## area id -> number of times entered (this session).
var visits: Dictionary = {}
var current_area: String = ""


func enter_area(area_id: String) -> void:
	var first := not visits.has(area_id)
	visits[area_id] = int(visits.get(area_id, 0)) + 1
	current_area = area_id
	area_entered.emit(area_id, first)


func fire(event_id: String, payload: Dictionary = {}) -> void:
	event_fired.emit(event_id, payload)


func has_visited(area_id: String) -> bool:
	return visits.has(area_id)
