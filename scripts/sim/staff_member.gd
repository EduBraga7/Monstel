class_name StaffMember
extends RefCounted
## Funcionário que circula pela escada de serviço (camareira).

enum St { IDLE, TRAVEL, CLEAN }

var type: StringName = &"maid"
var st: int = St.IDLE
var floor_f := 0.0
var prev_floor := 0.0
var x := 972.0
var timer := 0.0
var target_floor := -1
var target_bed := -1
