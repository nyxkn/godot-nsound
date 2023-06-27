class_name Bus
extends Node

var Log = preload("res://addons/nsound/logger.gd").new(self)

# ============================
# MAIN BUS
# ============================


# this is a class that encapsulates all bus-related functionality of AudioServer
# you can either wrap an existing audioserver bus
# or create a new one

#signal bus_initialized
#signal volume_changed(value)
signal auto_volume_changed(value: float)
signal user_volume_changed(value: float)


@export var mute: bool = false :
	set = set_mute
# solo is not very useful on chained buses
# all buses of the chain need to be soloed for them to play
# it's only useful for top-level buses really
#export var solo: bool := false : set = set_solo
# a disabled track won't be played by play_track() and _process won't run
# it's a simple true/false value
@export var disabled: bool = false :
	set = set_disabled


# we'd use MIN_DB but export doesn't seem to accept that
# this is the true volume. users are not supposed to interact with this
#export var _volume_db : get = get_volume_db, set = set_volume_db # (float, -80, 24)
var _volume_db: float :
	get = get_volume_db, set = set_volume_db

# this is the bus to which we send our output
@export var send: String :
	get = get_send, set = set_send


# automation volume. meant to be used mostly through fade
var _auto_volume_db: float = 0.0
var auto_volume_db: float :
	get: return _auto_volume_db
	set(v): set_auto_volume_db(v)

# volume set through the mixer or manually through code
# this is so that fades can happen independently of the real volume
@export var user_volume_db: float = 0.0 :
	set = set_user_volume_db


# fade variables
var fade_start_time: float
var fade_initial: float # [0,1]
var fade_final: float # [0,1]
var fade_duration: float
enum FadeType { IN, OUT }
var fade_type: int
var fade_blend: float

var fading: bool : set = set_fading

# last volume before fade
# useful for restoring the previous volume level we had before fading out
#var prefade_volume: float = 0


@onready var debug = get_tree().root.find_child("Debug", true, false)


func init(send_bus_name: String = "Master") -> Bus:
#	assert(0 == 1) #,"you should not be instancing the Bus class. consider this to be abstract")
	Log.w(["you have initialized the class Bus as", name, ". Bus should probably just be abstract"])
	self.send = send_bus_name
	return self


func _ready() -> void:
	pass
	self.fading = false


func set_fading(value):
	if disabled: return

	fading = value
	set_process(value)


func _process(delta: float) -> void:
	if fading:
		var t = inverse_lerp(fade_start_time, fade_start_time + fade_duration, Time.get_ticks_msec())

		if t >= 1.0:
#			Log.d(["final", _volume_db])
			self.fading = false

#			self._volume_db = linear_to_db(fade_final)
			self.auto_volume_db = linear_to_db(fade_final)
#			self.auto_volume_db = fade_final

		else:
			if fade_type == FadeType.IN:
				# if the signals are correlated (the same?), the fade should be linear
				# this means that when both signals meet at the middle (x=0.5)
				# then y=0.5 (0.5 translates to -6db)
				# so one signal follows f(x)=x, the other follows g(x)=1-x
				# the sum function is always 1: f(x) + g(x) = 1
				# if the signals are uncorrelated (not the same), the fade should be an equal power fade
				# this means that at x=0.5, y=0.5 * sqrt(2) ~= 0.707 (0.707 is -3db)
				# you can use any two functions where the sum of the square of the functions = 1
				# that is f(x)^2 + g(x)^2 = 1
				# you can then use a square function: f(x)=sqrt(x), g(x)=sqrt(1.0-x)
				# or a cos crossfade: f(x)=cos(x*pi/2), g(x)=cos((1-x)*pi/2)
				# https://dsp.stackexchange.com/questions/37477/understanding-equal-power-crossfades
				# this is because you want the power of the signals to stay constant
				# rather than the voltage
				var linear_t = t
				var square_t = sqrt(t)
				# we can choose the blend between linear and square
				# often signals aren't perfectly correlated or uncorrelated
				var t_final = lerp(linear_t, square_t, fade_blend)
#				self.auto_volume_db = linear_to_db( lerp(fade_initial, fade_final, t_final) )
				set_auto_volume_db(linear_to_db( lerp(fade_initial, fade_final, t_final) ), true)
			elif fade_type == FadeType.OUT:
				var linear_t = 1.0 - t
				var square_t = sqrt(1.0 - t)
				var t_final = lerp(linear_t, square_t, fade_blend)
				# note that we need to swap initial and final
#				self.auto_volume_db = linear_to_db( lerp(fade_final, fade_initial, t_final) )
				set_auto_volume_db(linear_to_db( lerp(fade_final, fade_initial, t_final) ), true)

#			debug.print(self.auto_volume_db, "db_" + name)

	#	if is_equal_approx(t, 0.5):
	#		Log.d([name, stream._volume_db, fade_type])


# we take the values in decibels but then convert to linear for calculations
func fade(initial, final, duration = 2.0, blend = 1.0):
	if duration <= 0:
		Log.e(["cannot use negative duration:", duration])

	if initial == null:
		initial = auto_volume_db

	if final == null:
		final = auto_volume_db
#		final = prefade_volume if prefade_volume else 0
#		Log.d(["fading to prefade_volume:", prefade_volume])


	fade_start_time = Time.get_ticks_msec()
	fade_initial = db_to_linear(initial)
	fade_final = db_to_linear(final)
	# using msec
	fade_duration = duration * 1000
	fade_blend = blend

	if fade_final > fade_initial:
		fade_type = FadeType.IN
	else:
		fade_type = FadeType.OUT
#		if initial != NDef.MIN_DB:
#			prefade_volume = _volume_db

	self.fading = true



func get_true_volume() -> float:
	var true_volume = db_to_linear(user_volume_db) * db_to_linear(auto_volume_db)
	return linear_to_db(true_volume)


func set_auto_volume_db(value: float, from_fade = false) -> void:
#func set_auto_volume_db(value: float) -> void:
	# if setting autovolume from fade process, skip the signal. it will get called at the end of the fade
	if not from_fade:
		if fading:
			Log.w("cancelling fade")
			self.fading = false

	_auto_volume_db = value
	self._volume_db = get_true_volume()
	auto_volume_changed.emit(auto_volume_db)


func set_user_volume_db(value: float) -> void:
	user_volume_db = value
	self._volume_db = get_true_volume()
	user_volume_changed.emit(user_volume_db)


func set_volume_db(value: float) -> void:
	_volume_db = value
#	emit_signal("volume_changed", _volume_db)
#	Log.d(["bus volume changed", name, AudioServer.get_bus_volume_db(bus_idx)])


func get_volume_db() -> float:
	return _volume_db


func set_send(value: String) -> void:
	send = value


func get_send() -> String:
	return send


func set_mute(value: bool) -> void:
	mute = value


#func set_solo(value: bool) -> void:
#	solo = value


func set_disabled(value: bool) -> void:
	set_process(!disabled)
	disabled = value
