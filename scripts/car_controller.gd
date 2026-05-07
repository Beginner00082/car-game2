extends VehicleBody3D
# CAR CONTROLLER - Fisica arcade stile Forza Horizon semplificato
# Controlli: W/S o Freccia Su/Giù = Accelera/Frena
# A/D o Freccia Sx/Dx = Sterza | Spazio = Freno a mano | Shift = Turbo

@export_group("Motore")
@export var engine_power := 300.0 # Potenza motore
@export var max_speed := 80.0 # km/h velocità massima
@export var turbo_power := 500.0 # Potenza extra col turbo
@export var turbo_duration := 3.0 # Secondi di turbo

@export_group("Sterzo")
@export var steer_speed := 3.0 # Velocità di sterzata
@export var max_steer_angle := 0.6 # Angolo massimo ruote
@export var steer_speed_reduction := 0.5 # Quanto sterza meno ad alta velocità

@export_group("Drift")
@export var drift_factor := 0.95 # Quanto scivola in drift
@export var handbrake_factor := 0.7 # Potenza freno a mano

@export_group("Sospensioni")
@export var suspension_stiffness := 40.0
@export var suspension_travel := 0.3
@export var wheel_friction := 2.5

# Nodi interni
@onready var back_left_wheel := $WheelBackLeft
@onready var back_right_wheel := $WheelBackRight
@onready var front_left_wheel := $WheelFrontLeft
@onready var front_right_wheel := $WheelFrontRight

# Variabili runtime
var current_speed := 0.0
var is_drifting := false
var turbo_active := false
var turbo_time_left := 0.0

func _ready():
	# Setup sospensioni per tutte le ruote
	for wheel in [back_left_wheel, back_right_wheel, front_left_wheel, front_right_wheel]:
		wheel.suspension_stiffness = suspension_stiffness
		wheel.suspension_travel = suspension_travel
		wheel.wheel_friction_slip = wheel_friction
	
	# Le ruote posteriori hanno trazione
	back_left_wheel.use_as_traction = true
	back_right_wheel.use_as_traction = true
	
	# Le ruote anteriori sterzano
	front_left_wheel.use_as_steering = true
	front_right_wheel.use_as_steering = true

func _physics_process(delta):
	current_speed = linear_velocity.length() * 3.6 # Converti in km/h
	handle_input(delta)
	handle_drift()
	handle_turbo(delta)
	apply_speed_limit()

func handle_input(delta):
	# ACCELERAZIONE + FRENO
	var throttle = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	var current_power = engine_power
	if turbo_active:
		current_power = turbo_power
	
	engine_force = throttle * current_power
	
	# STERZO - meno sensibile ad alta velocità
	var steer_input = Input.get_axis("ui_right", "ui_left")
	var speed_factor = clamp(1.0 - (current_speed / max_speed) * steer_speed_reduction, 0.3, 1.0)
	var target_steer = steer_input * max_steer_angle * speed_factor
	steering = move_toward(steering, target_steer, steer_speed * delta)
	
	# FRENO A MANO
	if Input.is_action_pressed("ui_select"): # Spazio
		brake = 10.0
		back_left_wheel.wheel_friction_slip = handbrake_factor
		back_right_wheel.wheel_friction_slip = handbrake_factor
		is_drifting = true
	else:
		brake = 0.0
		back_left_wheel.wheel_friction_slip = wheel_friction
		back_right_wheel.wheel_friction_slip = wheel_friction
		is_drifting = false
	
	# TURBO con Shift
	if Input.is_action_just_pressed("turbo") and turbo_time_left <= 0:
		activate_turbo()

func handle_drift():
	if is_drifting and current_speed > 20.0:
		# Riduci grip laterale per driftare
		var drift_vec = -global_transform.basis.z.slide(global_transform.basis.y).normalized()
		apply_central_force(drift_vec * current_speed * drift_factor)

func activate_turbo():
	turbo_active = true
	turbo_time_left = turbo_duration
	print("TURBO ATTIVATO!")

func handle_turbo(delta):
	if turbo_active:
		turbo_time_left -= delta
		if turbo_time_left <= 0:
			turbo_active = false
			print("Turbo finito")

func apply_speed_limit():
	if current_speed > max_speed and not turbo_active:
		linear_velocity = linear_velocity.normalized() * (max_speed / 3.6)

func get_speed_kmh() -> float:
	return current_speed

func is_turbo_active() -> bool:
	return turbo_active
