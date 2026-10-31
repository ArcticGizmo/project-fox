class_name StaffMelee
extends Node3D
## Wooden staff melee: a ground combo (length = tuning.melee_damage.size()),
## a straight-down ground slam, and a long-jump pounce that ends in a slam.
## Lives under the player's visual so it faces with the fox. The player asks
## for attacks and reads `phase` to drive movement; this node owns timing,
## hitboxes and the staff's pose.

signal swung(index: int)
signal slammed(at: Vector3)

enum Phase { IDLE, SWING, SLAM_HOVER, SLAM_FALL, POUNCE, SLAM_RECOVER }

const STAFF_COLOR := Color(0.55, 0.36, 0.18)
const SLAM_ACTIVE_TIME := 0.1

var tuning: PlayerTuning
var phase: Phase = Phase.IDLE
var phase_time: float = 0.0
var combo_index: int = -1
var hit_box: HitBox
var slam_box: HitBox

## Buffered presses (max 2) so mashing never drops a swing at a chain boundary.
var _queued: int = 0
var _since_combo_end: float = INF
var _slam_active_left: float = 0.0
var _swing_shape: BoxShape3D
var _swing_cs: CollisionShape3D
var _slam_shape: SphereShape3D
var _pivot: Node3D


func _ready() -> void:
	name = "StaffMelee"
	hit_box = HitBox.new()
	hit_box.name = "StaffHitBox"
	hit_box.collision_mask = Layers.ENEMY_HURTBOX
	hit_box.knockback_up = 2.5
	_swing_shape = BoxShape3D.new()
	_swing_cs = CollisionShape3D.new()
	_swing_cs.shape = _swing_shape
	hit_box.add_child(_swing_cs)
	add_child(hit_box)

	slam_box = HitBox.new()
	slam_box.name = "SlamHitBox"
	slam_box.collision_mask = Layers.ENEMY_HURTBOX
	slam_box.outline_when_inactive = false
	_slam_shape = SphereShape3D.new()
	_slam_shape.radius = tuning.slam_radius
	var scs := CollisionShape3D.new()
	scs.shape = _slam_shape
	scs.position.y = 0.5
	slam_box.add_child(scs)
	add_child(slam_box)

	_pivot = Node3D.new()
	_pivot.name = "StaffPivot"
	_pivot.position = Vector3(0.3, 1.1, 0.0)
	add_child(_pivot)
	var staff := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 1.8)
	staff.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STAFF_COLOR
	staff.material_override = mat
	staff.position = Vector3(0, 0, -0.75)
	_pivot.add_child(staff)
	_set_swing_shape(0)
	_pose(idle_pose())


func combo_length() -> int:
	return tuning.melee_damage.size()


func is_busy() -> bool:
	return phase != Phase.IDLE


func is_slamming() -> bool:
	return phase == Phase.SLAM_HOVER or phase == Phase.SLAM_FALL or phase == Phase.POUNCE


## Can a dodge/jump interrupt right now? Swings can always be dodge-cancelled;
## the slam commits until it lands.
func can_cancel() -> bool:
	return phase == Phase.SWING or phase == Phase.SLAM_RECOVER or phase == Phase.IDLE


## Called when melee is pressed. `on_floor` picks combo vs air attack;
## `stick` (world space, may be zero) picks slam vs pounce in the air.
## Returns the phase that was started (or IDLE if the press was buffered/ignored).
func request_attack(on_floor: bool, stick: Vector3) -> Phase:
	match phase:
		Phase.SWING:
			_queued = mini(_queued + 1, 2)
			return Phase.IDLE
		Phase.IDLE:
			if on_floor:
				var next := 0
				if _since_combo_end <= tuning.melee_combo_grace and combo_index + 1 < combo_length():
					next = combo_index + 1
				_start_swing(next)
				return Phase.SWING
			if tuning.pounce_enabled and stick.length_squared() > 0.25:
				_enter(Phase.POUNCE)
				return Phase.POUNCE
			_enter(Phase.SLAM_HOVER)
			return Phase.SLAM_HOVER
	return Phase.IDLE


func cancel() -> void:
	if phase == Phase.SWING:
		_since_combo_end = 0.0
	hit_box.active = false
	_queued = 0
	_enter(Phase.IDLE)


## Called by the player when it touches the ground during a slam or pounce.
func land(at: Vector3) -> void:
	if phase != Phase.SLAM_FALL and phase != Phase.POUNCE:
		return
	slam_box.damage = tuning.slam_damage
	slam_box.knockback = tuning.slam_knockback
	slam_box.knockback_up = tuning.slam_knockback_up
	slam_box.hit_stop = 0.06
	slam_box.active = true
	_slam_active_left = SLAM_ACTIVE_TIME
	_enter(Phase.SLAM_RECOVER)
	GameFeel.shake(0.45)
	GameFeel.impact(at + Vector3.UP * 0.2, Color(0.9, 0.75, 0.5, 0.6), tuning.slam_radius * 2.0, 0.25)
	DebugSettings.flash_sphere(at + Vector3.UP * 0.5, tuning.slam_radius, Color(1, 0.2, 0.1), 0.3)
	slammed.emit(at)


func update(delta: float) -> void:
	phase_time += delta
	_since_combo_end += delta
	if _slam_active_left > 0.0:
		_slam_active_left -= delta
		if _slam_active_left <= 0.0:
			slam_box.active = false
	match phase:
		Phase.SWING:
			hit_box.active = phase_time >= tuning.melee_active_start and phase_time <= tuning.melee_active_end
			if phase_time >= tuning.melee_swing_time[combo_index]:
				hit_box.active = false
				if _queued > 0 and combo_index + 1 < combo_length():
					_start_swing(combo_index + 1)
				else:
					_queued = 0
					_since_combo_end = 0.0
					if combo_index + 1 >= combo_length():
						combo_index = -1
					_enter(Phase.IDLE)
		Phase.SLAM_HOVER:
			if phase_time >= tuning.slam_hover_time:
				_enter(Phase.SLAM_FALL)
		Phase.SLAM_RECOVER:
			if phase_time >= tuning.slam_recovery:
				combo_index = -1
				_enter(Phase.IDLE)
	_update_pose()


func _start_swing(index: int) -> void:
	combo_index = index
	_queued = maxi(0, _queued - 1)
	_set_swing_shape(index)
	hit_box.damage = tuning.melee_damage[index]
	hit_box.knockback = tuning.melee_knockback[index]
	hit_box.hit_stop = tuning.melee_hit_stop[index]
	hit_box.active = false
	_enter(Phase.SWING)
	swung.emit(index)


func _enter(p: Phase) -> void:
	phase = p
	phase_time = 0.0


func is_finisher(index: int) -> bool:
	return index == combo_length() - 1


func _set_swing_shape(index: int) -> void:
	if is_finisher(index):
		_swing_shape.size = Vector3(3.0, 2.0, 2.6)
		_swing_cs.position = Vector3(0, 0.9, -1.45)
	else:
		_swing_shape.size = Vector3(2.6, 1.6, 2.2)
		_swing_cs.position = Vector3(0, 0.9, -1.25)
	hit_box.refresh_outline()


# --- Staff pose (pure presentation) --------------------------------------------

## Euler degrees for the staff pivot: x = pitch (+ raises the tip), y = yaw (+ = left).
func idle_pose() -> Vector3:
	return Vector3(115, 0, 35)


func _update_pose() -> void:
	match phase:
		Phase.SWING:
			var t := ease(clampf(phase_time / tuning.melee_active_end, 0.0, 1.0), 0.4)
			if is_finisher(combo_index):
				_pose(Vector3(lerpf(100.0, -35.0, t), 0, 0))
			elif combo_index % 2 == 0:
				_pose(Vector3(-10, lerpf(-85.0, 85.0, t), 0))
			else:
				_pose(Vector3(-10, lerpf(85.0, -85.0, t), 0))
		Phase.SLAM_HOVER, Phase.POUNCE:
			_pose(Vector3(100, 0, 0))
		Phase.SLAM_FALL, Phase.SLAM_RECOVER:
			_pose(Vector3(-55, 0, 0))
		_:
			_pose(idle_pose())


func _pose(euler_deg: Vector3) -> void:
	_pivot.basis = Basis.from_euler(Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z)))
