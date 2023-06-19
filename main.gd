@tool
extends Node3D

## This is not a simulation of the actual model but only a extremely simplified version.
## I don't know if I made some mistakes in my assumptions. I haven't found a similar solution anywhere.
## Most were even more simplified or much more complicated.

const HOURS_IN_DAY : float = 24.0
const DAYS_IN_YEAR : int = 365

# For simplify, a local time, I skip totally a longitude
@export_range( 0.0, HOURS_IN_DAY, 0.0001 ) var day_time : float = 0.0 :
	set( value ) :
		day_time = value
		if day_time < 0.0 :
			day_time += HOURS_IN_DAY
			day_of_year -= 1
		elif day_time > HOURS_IN_DAY :
			day_time -= HOURS_IN_DAY
			day_of_year += 1
		_update()
@export_range( -90.0, 90.0, 0.01 ) var latitude : float = 0 :
	set( value ) :
		latitude = value
		_update()
## Day of year. In game, if you reach DAYS_IN_YEAR, don't set 0 to keep correct position of the moon
@export_range( 1, DAYS_IN_YEAR, 1 ) var day_of_year : int = 1 :
	set( value ) :
		day_of_year = value
		_update()
## The tilt of the rotational axis resulting in the occurrence of seasons
@export_range( -180.0, 180.0, 0.01 ) var planet_axial_tilt : float = 23.44 :
	set( value ) :
		planet_axial_tilt = value
		_update()
# The deviation of the moon's orbit from the earth's orbit
@export_range( -180.0, 180.0, 0.01 ) var moon_orbital_inclination : float = 5.14:
	set( value ) :
		moon_orbital_inclination = value
		_update_moon()
## Time required for the moon to orbit around the earth (in days = one rotation of the earth around its own axis)
@export_range( 0.1, DAYS_IN_YEAR, 0.01 ) var moon_orbital_period : float = 29.5 :
	set( value ) :
		moon_orbital_period = value
		_update_moon()
@export_range( 0.0, 1.0, 0.01 ) var clouds_cutoff : float = 0.3 :
	set( value ) :
		clouds_cutoff = value
		_update_clouds()
@export_range( 0.0, 1.0, 0.01 ) var clouds_weight : float = 0.0 :
	set( value ) :
		clouds_weight = value
		_update_clouds()
## If on, the sum of day_of_year and day_time will be passed to the sky shadader to use instead of TIME from the engine
@export var use_day_time_for_shader : bool = false :
	set( value ) :
		use_day_time_for_shader = value
		_update_shader()
## Multiplier of the elapsed time in the running game.
## If 0.0 - day time will not be changed automatically.
## If 1.0 - one hour will take one second.
@export_range( 0.0, 1.0, 0.0001 ) var time_scale : float = 0.01 :
	set( value ) :
		time_scale = value
## If 0, the value will set from the sun object, but as the script runs in the editor, it may set the wrong value, so it is best to set it manually.
@export_range( 0.0, 10.0, 0.01 ) var sun_base_enegry : float = 0.0 :
	set( value ) :
		sun_base_enegry = value
		_update_shader()
## If 0, the value will set from the moon object, but as the script runs in the editor, it may set the wrong value, so it is best to set it manually.
@export_range( 0.0, 10.0, 0.01 ) var moon_base_enegry : float = 0.0 :
	set( value ) :
		moon_base_enegry = value
		_update_shader()

@onready var environment : WorldEnvironment = $WorldEnvironment
@onready var sun : DirectionalLight3D = $Sun
@onready var moon : DirectionalLight3D = $Moon

func _ready() -> void :
	if is_instance_valid( sun ) :
		sun.position = Vector3( 0.0, 0.0, 0.0 )
		sun.rotation = Vector3( 0.0, 0.0, 0.0 )
		sun.rotation_order = EULER_ORDER_ZXY
		if sun_base_enegry == 0.0 :
			sun_base_enegry = sun.light_energy
	if is_instance_valid( moon ) :
		moon.position = Vector3( 0.0, 0.0, 0.0 )
		moon.rotation = Vector3( 0.0, 0.0, 0.0 )
		moon.rotation_order = EULER_ORDER_ZXY
		if moon_base_enegry == 0.0 :
			moon_base_enegry = moon.light_energy
	_update()

func _process( delta: float ) -> void :
	if not Engine.is_editor_hint() : # We don't want a time lapse in the editor
		day_time += delta * time_scale

func _update() -> void :
	_update_sun()
	_update_moon()
	_update_clouds()
	_update_shader()

func _update_sun() -> void :
	if is_instance_valid( sun ) :
		var day_progress : float = day_time / HOURS_IN_DAY
		# Sunset and sunrise
		sun.rotation.x = ( day_progress * 2.0 - 0.5 ) * -PI
		# 193 is the number of days from the summer solstice to the end of the year.
		# Here we want 0 for the summer solstice and 1 for the winter solstice.
		var earth_orbit_progress = ( float( day_of_year ) + 193.0 + day_progress ) / float( DAYS_IN_YEAR )
		# Rotation to the deviation of the axis of rotation from the orbit.
		# This gives us shorter days in winter and longer days in summer.
		sun.rotation.y = deg_to_rad( cos( earth_orbit_progress * PI * 2.0 ) * planet_axial_tilt )
		sun.rotation.z = deg_to_rad( latitude )
		# Disabling light under the horizon
		var sun_direction = sun.to_global( Vector3( 0.0, 0.0, 1.0 )).normalized()
		sun.light_energy = smoothstep( -0.05, 0.1, sun_direction.y ) * sun_base_enegry

func _update_moon() -> void :
	var day_progress : float = day_time / HOURS_IN_DAY
	if is_instance_valid( moon ) :
		# Progress of the moon's orbital rotation in days
		var moon_orbit_progress : float = ( fmod( float( day_of_year ), moon_orbital_period ) + day_progress ) / moon_orbital_period
		moon.rotation.x = (( day_progress - moon_orbit_progress ) * 2.0 - 1.0 ) * PI
		var axial_tilt = moon_orbital_inclination
		# Adding a planet axial tilt depending on the time of day
		axial_tilt += planet_axial_tilt * sin(( day_progress * 2.0 - 1.0 ) * PI )
		moon.rotation.y = deg_to_rad( axial_tilt )
		moon.rotation.z = deg_to_rad( latitude )
		# Disabling light under the horizon
		var moon_direction = moon.to_global( Vector3( 0.0, 0.0, 1.0 )).normalized()
		moon.light_energy = smoothstep( -0.05, 0.1, moon_direction.y ) * moon_base_enegry

func _update_clouds() -> void :
	if is_instance_valid( environment ) :
		environment.environment.sky.sky_material.set_shader_parameter( "clouds_cutoff", clouds_cutoff )
		environment.environment.sky.sky_material.set_shader_parameter( "clouds_weight", clouds_weight )

func _update_shader() -> void :
	if is_instance_valid( environment ) :
		environment.environment.sky.sky_material.set_shader_parameter(
			"overwritten_time",
			( day_of_year * HOURS_IN_DAY + day_time ) * 100.0 if use_day_time_for_shader else 0.0
		)
