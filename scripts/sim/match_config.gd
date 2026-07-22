class_name MatchConfig
extends RefCounted
## "A match" as a small config object (spec §17 guardrail 5): who's playing, the
## shared seed, and the level. One local player today; the same shape carries
## player + ghost, or two networked players, without restructuring the flow.
##
## Named `match_seed` (not `seed`) to avoid shadowing GDScript's global seed().

var players: int = 1
var match_seed: int = 0
var level: LevelDef = null


static func single_player(level: LevelDef, seed_value: int) -> MatchConfig:
	var m := MatchConfig.new()
	m.players = 1
	m.match_seed = seed_value
	m.level = level
	return m
