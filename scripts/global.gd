extends Node

signal run_started(level_number: int)
signal run_stats_changed(time: float, deaths: int, gravity_switches: int)
signal level_completed(stats: Dictionary)
signal best_scores_changed

const MAX_LEVEL := 10
const LEVEL_SCENE_PATTERN := "res://scenes/level_%d.tscn"
const SAVE_PATH := "user://gravrun_scores.save"

var current_level := 1
var run_time := 0.0
var run_deaths := 0
var run_gravity_switches := 0
var run_active := false
var best_scores: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_best_scores()

func _process(delta: float) -> void:
	if not run_active or get_tree().paused:
		return

	run_time += delta
	run_stats_changed.emit(run_time, run_deaths, run_gravity_switches)

func start_level(level_number: int) -> void:
	current_level = clampi(level_number, 1, MAX_LEVEL)
	run_time = 0.0
	run_deaths = 0
	run_gravity_switches = 0
	run_active = true
	get_tree().paused = false
	run_started.emit(current_level)
	run_stats_changed.emit(run_time, run_deaths, run_gravity_switches)

func load_level(level_number: int) -> void:
	var target := LEVEL_SCENE_PATTERN % clampi(level_number, 1, MAX_LEVEL)
	get_tree().change_scene_to_file(target)

func restart_current_level() -> void:
	load_level(current_level)

func record_death() -> void:
	run_deaths += 1
	run_stats_changed.emit(run_time, run_deaths, run_gravity_switches)

func record_gravity_switch() -> void:
	run_gravity_switches += 1
	run_stats_changed.emit(run_time, run_deaths, run_gravity_switches)

func complete_level() -> Dictionary:
	run_active = false
	var stats := get_current_stats()
	stats["score"] = calculate_score(stats)
	stats["best_score"] = get_best_score(current_level)

	if int(stats["score"]) > int(stats["best_score"]):
		best_scores[str(current_level)] = stats["score"]
		stats["best_score"] = stats["score"]
		save_best_scores()
		best_scores_changed.emit()

	level_completed.emit(stats)
	return stats

func get_current_stats() -> Dictionary:
	return {
		"level": current_level,
		"time": run_time,
		"deaths": run_deaths,
		"gravity_switches": run_gravity_switches,
	}

func calculate_score(stats: Dictionary) -> int:
	var level := int(stats.get("level", current_level))
	var par_time := 35.0 + float(level) * 16.0
	var time_over_par: float = maxf(0.0, float(stats["time"]) - par_time)
	var time_score: float = maxf(0.0, 7000.0 - time_over_par * 85.0)
	var death_penalty: int = int(stats["deaths"]) * 700
	var switch_budget: int = 5 + level * 3
	var switch_penalty: int = maxi(0, int(stats["gravity_switches"]) - switch_budget) * 120
	var mastery_bonus: float = maxf(0.0, par_time - float(stats["time"])) * 35.0
	return maxi(0, int(round(time_score + mastery_bonus - death_penalty - switch_penalty)))

func get_best_score(level_number: int) -> int:
	return int(best_scores.get(str(level_number), 0))

func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var whole_seconds := int(seconds) % 60
	var centiseconds := int((seconds - floor(seconds)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, whole_seconds, centiseconds]

func save_best_scores() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(best_scores)

func load_best_scores() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var data = file.get_var()
	if data is Dictionary:
		best_scores = data

func play_sfx(type: String) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	
	var duration: float = 0.1
	match type:
		"switch":
			duration = 0.22
		"regen":
			duration = 0.13
		"hover":
			duration = 0.04
		"click":
			duration = 0.08
		"complete":
			duration = 0.39
		"death":
			duration = 0.4
			
	stream.buffer_length = duration + 0.05
	player.stream = stream
	player.volume_db = -12.0
	if type == "hover":
		player.volume_db = -24.0
	elif type == "complete":
		player.volume_db = -8.0
	
	add_child(player)
	player.play()
	
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		player.queue_free()
		return
		
	var mix_rate: float = stream.mix_rate
	var frames: int = int(mix_rate * duration)
	
	for i in frames:
		var t: float = float(i) / mix_rate
		var sample: float = 0.0
		
		match type:
			"switch":
				# Sweep down from 500Hz to 150Hz
				var freq: float = lerp(500.0, 150.0, t / duration)
				sample = sin(t * freq * TAU) * 0.22
				if t > duration - 0.04:
					sample *= (duration - t) / 0.04
			"regen":
				# C5 (523Hz) then E5 (659Hz)
				var freq: float = 523.25
				if t > 0.05:
					freq = 659.25
				sample = sin(t * freq * TAU) * 0.15
				if t > duration - 0.03:
					sample *= (duration - t) / 0.03
			"hover":
				# Quick tick
				var freq: float = 900.0
				sample = sin(t * freq * TAU) * 0.08 * exp(-120.0 * t)
			"click":
				# Solid click
				var freq: float = 440.0
				sample = sin(t * freq * TAU) * 0.18 * exp(-60.0 * t)
			"complete":
				# Arpeggio
				var freq: float = 523.25
				if t > 0.24:
					freq = 1046.50
				elif t > 0.16:
					freq = 783.99
				elif t > 0.08:
					freq = 659.25
				sample = sin(t * freq * TAU) * 0.16
				if t > duration - 0.05:
					sample *= (duration - t) / 0.05
			"death":
				var freq: float = lerp(200.0, 50.0, t / duration)
				sample = sin(t * freq * TAU) * 0.2
				if int(t * freq * 2.0) % 2 == 0:
					sample += sin(t * freq * 2.0 * TAU) * 0.05
				if t > duration - 0.06:
					sample *= (duration - t) / 0.06
					
		playback.push_frame(Vector2(sample, sample))
		
	get_tree().create_timer(duration + 0.05, true, false, true).timeout.connect(player.queue_free)

