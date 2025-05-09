extends CharacterBody2D

@onready var throw_charge_timer: Timer = $ThrowChargeTimer
@onready var player_state_machine: PlayerStateMachine = $PlayerStateMachine
@onready var audio_player: Node2D = $AudioPlayer
@onready var character_animation: Node2D = $"Character Animation"
@onready var rod: Node2D = $Rod

signal throw_hook(throw_distance)
signal retract_hook
signal reeling
signal relaxing
signal max_tension

const SPEED = 5000.0
const MAX_HOOK_THROW_DISTANCE = 500
const MAX_TENSION = 300
const MIN_TENSION = 0

var rod_controllable: bool = true
var tension = 0
var tension_increase = 100
var raise_tension = false
var shake = 1

func _ready() -> void:
	Global.player = self
	reset_rod_target()

func _physics_process(delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if Input.is_action_pressed("player_move_left"):
		velocity.x = -SPEED * delta
		character_animation.play_animation("Walk_Left")
	elif Input.is_action_pressed("player_move_right"):
		velocity.x = SPEED * delta
		character_animation.play_animation("Walk_Right")
	else:
		velocity.x = 0
		character_animation.play_animation("Idle")
	
	#Walking sound effects
	if velocity.x != 0:
		if !audio_player.is_playing("WalkingSFX"):
			audio_player.play_sound("WalkingSFX")
	elif audio_player.is_playing("WalkingSFX"):
		audio_player.stop_sound("WalkingSFX")
	
	if raise_tension:
		tension += tension_increase * delta
	else:
		tension = max(tension - 150 * delta, MIN_TENSION)
	
	if tension >= MAX_TENSION:
		max_tension.emit()
		stop_reeling()
		
	if tension > MAX_TENSION * 0.7:
		shake *= -1
		character_animation.position.x += 5 * shake
		
	move_and_slide()

func _on_idle_charge_hook() -> void:
	rod.play_animation("Wind")
	throw_charge_timer.wait_time = 2
	throw_charge_timer.start()

func _on_idle_throw_hook() -> void:
	var charge_percentage: float = 1-throw_charge_timer.time_left/throw_charge_timer.wait_time
	throw_charge_timer.stop()
	var throw_distance = MAX_HOOK_THROW_DISTANCE * charge_percentage
	rod.play_animation("Cast")
	rod.seek(charge_percentage)
	throw_hook.emit(throw_distance)
	if charge_percentage <= 0.5:
		audio_player.play_sound("RodThrowShort")
	else:
		audio_player.play_sound("RodThrowLong")

func _on_waiting_retract_hook() -> void:
	reset_rod_target()
	retract_hook.emit()

func begin_reeling(Fish: Global.Fish):
	match Fish:
		Global.Fish.BrookTrout || Global.Fish.BrownTrout:
			pass
		Global.Fish.Carp || Global.Fish.Dab:
			tension_increase = 110
		Global.Fish.Muskellunge:
			tension_increase = 120
	player_state_machine.on_child_transition("Reeling")
	
func begin_reeling_collectible():
	player_state_machine.on_child_transition("Reeling")

func _on_reeling_reeling() -> void:
	raise_tension = true
	tension += 30
	reeling.emit()
	if !audio_player.is_playing("ReelingSFX"):
		audio_player.play_sound("ReelingSFX")

func _on_reeling_relaxing() -> void:
	raise_tension = false
	relaxing.emit()
	if audio_player.is_playing("ReelingSFX"):
		audio_player.stop_sound("ReelingSFX")

func stop_reeling():
	reset_rod_target()
	raise_tension = false
	player_state_machine.on_child_transition("Idle")
	if audio_player.is_playing("ReelingSFX"):
		audio_player.stop_sound("ReelingSFX")

func get_rod_tip_global_position() -> Vector2:
	return rod.get_rod_tip_global_position()

func set_rod_bend_target(target_position: Vector2):
	rod.set_target(target_position)

func reset_rod_target():
	rod.reset_target()
