class_name LevelMetrics
extends RefCounted
## Level-design limits for blocking out, in metres. They come from real jumps
## measured by tests/unit/test_jump_metrics.gd (which fails if the player can no
## longer reach the path limits, or can now reach the gadget-gate minimums), and
## test_slice.gd checks the slice's critical path against them.
##
## Critical-path geometry: Blocks in group "critical_path" (see CLAUDE.md).

## Tolerance kept between a design limit and the measured limit.
const MARGIN := 0.3

## Highest step the critical path asks for with a single jump.
const STEP_MAX := 1.5
## Highest ledge on the critical path (double jump).
const LEDGE_MAX := 3.0
## Widest gap the path asks for with a single jump.
const SINGLE_GAP_MAX := 4.0
## Widest gap on the critical path (double jump at the apex).
const GAP_MAX := 7.5
## A ledge behind a gadget gate is at least this high...
const GATE_LEDGE_MIN := 5.5
## ...and a gated gap at least this wide.
const GATE_GAP_MIN := 13.0
