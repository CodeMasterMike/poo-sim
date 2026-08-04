class_name Palette
extends RefCounted
## The locked palette — the single source of truth for UI colour.
## See docs/specs/poo-sim-style-guide.html for roles, the meter colour language,
## and the rest of the style guide. Views ALIAS these constants instead of
## redefining Color() literals, so the palette can never silently drift across
## screens again. Hex form matches the style guide's token block.
##
## Pure constants: never instantiated — referenced as Palette.FLOW, etc.

const BG        := Color("171A1F")  ## app background — everything sits on this
const PANEL     := Color("262B36")  ## cards, tracks, gauge housing
const DEAD      := Color("303B4A")  ## the dead zone
const BORDER    := Color("4D576B")  ## hairlines / outlines on dark UI
const FLOW      := Color("3DD166")  ## GO / safe / good
const FLOW_DIM  := Color("266B40")  ## flow, inactive / off-target
const RED       := Color("EB4D40")  ## DANGER / greed
const RED_DIM   := Color("6B3030")  ## red zone, inactive
const AMBER     := Color("F2BF40")  ## CAUTION / incoming
const ORANGE    := Color("FA8C26")  ## hot accent — a live prompt; sparingly
const GOAL      := Color("F5EB6B")  ## reward — goal line, stars, titles
const NEEDLE    := Color("FAFCFF")  ## pure white — the needle & key marks only
const TEXT      := Color("EBF0FA")  ## primary text on dark
const TEXT_DIM  := Color("94A1B5")  ## secondary text, labels, hints

## The modal scrim behind overlays (manual, picker). Translucent, so it's its own
## token rather than a surface tone.
const SCRIM     := Color("12141A", 0.92)

# --- Representational colour ---------------------------------------------
# The only hues here that depict a THING rather than carry a meaning. They live
# in the palette anyway so they can't drift, but they are explicitly NOT
# semantic: unlike FLOW/RED/AMBER they never signal state, and nothing should
# ever read a rule from them. Two matter tones exactly, because the style guide
# (§5) allows a flat fill plus one shadow tone and no more.

const MATTER      := Color("6B4A2B")  ## the product — flat fill
const MATTER_DARK := Color("422C17")  ## the product — its single shadow tone
const WATER       := Color("2B4B58")  ## bowl water, before anything lands in it
