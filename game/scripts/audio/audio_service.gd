extends Node
## Autoload "Audio": plays sound cues (SoundBank, SoundFiles) and music, and
## owns the buses and their volumes. Gameplay never waits on it and it never
## changes gameplay: every call is fire-and-forget.
##
## Buses (made here, so the project needs no bus layout file):
##   Master ← Sfx (the effects volume) ← World (with a light reverb), Ui, Ambience
##   Master ← Music (the music volume)
##
## World sounds play from a pool of 3D players that pause with the game; the
## listener is the camera rig's (IsometricCameraRig), at the hero, so sounds
## pan with the screen. Interface sounds and music keep playing while paused;
## the music dips while the game waits.

## Voices for sounds placed in the world. When all are busy the oldest is
## cut, so a crowded fight cannot pile up sounds on a phone.
const WORLD_VOICES := 16
## Voices for interface sounds and stingers.
const FLAT_VOICES := 6
## Seconds a track takes to fade into the next.
const CROSSFADE := 1.5
## How far below its level the music sits while the game is paused.
const DUCK_DB := -9.0
## Headroom: a busy fight measures about -16 LUFS, a usual level for mobile.
const MASTER_TRIM_DB := -2.0
const WORLD_TRIM_DB := -6.0
## The cue names played most recently, newest last (tests read it).
const HISTORY_SIZE := 64

var history: Array[StringName] = []
## The music track playing (a SoundBank.TRACKS key), or &"".
var music_track: StringName = &""
## The background bed playing, or &"".
var ambience_track: StringName = &""

var _streams: Dictionary[StringName, Array] = {}
## When each cue last played, on `_clock`.
var _last_played: Dictionary[StringName, float] = {}
## Seconds of frames, unscaled by hit-stop: the clock the gaps are kept on.
var _clock: float = 0.0
var _world_voices: Array[AudioStreamPlayer3D] = []
var _flat_voices: Array[AudioStreamPlayer] = []
var _next_world: int = 0
var _next_flat: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _music_tween: Tween
var _ambience: AudioStreamPlayer
var _ducked: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	var world := Node.new()
	world.name = "World"
	# The world's sounds stop when the game pauses and go on when it resumes.
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	for i in WORLD_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = SoundBank.WORLD
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 8.0
		voice.max_distance = 45.0
		voice.panning_strength = 0.6
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		world.add_child(voice)
		_world_voices.append(voice)
	for i in FLAT_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_flat_voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = SoundBank.MUSIC
		add_child(player)
		_music.append(player)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = SoundBank.AMBIENCE
	add_child(_ambience)
	var settings := get_node_or_null(^"/root/Settings")
	if settings:
		settings.changed.connect(apply_volumes)
		apply_volumes(settings.current)
	# Every button in the game clicks when pressed.
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.01)


## Plays `cue`: from world position `at` when given, else flat (the
## interface). `pitch` scales the cue's own pitch (bigger creatures sound
## deeper) and `volume_db` adds to its loudness. Returns false when it did
## not play: an unknown cue, or the same cue played less than its gap ago.
func play(cue: StringName, at: Vector3 = Vector3.INF, pitch: float = 1.0, volume_db: float = 0.0) -> bool:
	if cue == &"" or not SoundBank.has(cue):
		return false
	var mix := SoundBank.mix(cue)
	if _clock - _last_played.get(cue, -1000.0) < mix.gap:
		return false
	_last_played[cue] = _clock
	var stream := _pick(cue)
	if stream == null:
		return false
	var final_pitch: float = pitch * (1.0 + _rng.randf_range(-mix.pitch, mix.pitch))
	var bus: StringName = mix.bus
	if at != Vector3.INF and bus == SoundBank.WORLD:
		var voice := _world_voices[_next_world]
		_next_world = (_next_world + 1) % _world_voices.size()
		voice.stop()
		voice.stream = stream
		voice.volume_db = mix.db + volume_db
		voice.pitch_scale = maxf(final_pitch, 0.05)
		voice.global_position = at
		voice.play()
	else:
		var voice := _flat_voices[_next_flat]
		_next_flat = (_next_flat + 1) % _flat_voices.size()
		voice.stop()
		voice.stream = stream
		voice.bus = bus if bus != SoundBank.WORLD else SoundBank.UI
		voice.volume_db = mix.db + volume_db
		voice.pitch_scale = maxf(final_pitch, 0.05)
		voice.play()
	history.append(cue)
	if history.size() > HISTORY_SIZE:
		history.pop_front()
	return true


## Fades to music `track` (a SoundBank.TRACKS key; &"" fades out). Playing
## the track already playing changes nothing.
func play_music(track: StringName, fade: float = CROSSFADE) -> void:
	if track == music_track:
		return
	music_track = track
	if _music_tween:
		_music_tween.kill()
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var new := _music[_music_index]
	_music_tween = create_tween().set_parallel()
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -60.0, fade)
		_music_tween.chain().tween_callback(old.stop)
	if track == &"":
		return
	new.stream = _looping(track)
	new.volume_db = -60.0
	new.play()
	_music_tween.tween_property(new, "volume_db", _music_level(track), fade)


## Plays background bed `track` under the music (&"" stops it).
func play_ambience(track: StringName) -> void:
	if track == ambience_track:
		return
	ambience_track = track
	_ambience.stop()
	if track == &"":
		return
	_ambience.stream = _looping(track)
	_ambience.volume_db = SoundBank.TRACKS.get(track, -12.0)
	_ambience.play()


## Dips the music while the game waits (pause, bag, skills).
func set_ducked(ducked: bool) -> void:
	if ducked == _ducked:
		return
	_ducked = ducked
	if music_track == &"":
		return
	var player := _music[_music_index]
	if _music_tween and _music_tween.is_running():
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", _music_level(music_track), 0.3)


func is_ducked() -> bool:
	return _ducked


## Sets the bus volumes from `settings` (music and effects, 0 to 1).
func apply_volumes(settings: GameSettings) -> void:
	_set_bus_volume(SoundBank.MUSIC, settings.music_volume)
	_set_bus_volume(&"Sfx", settings.effects_volume)


## Stops every sound and the music at once (tests, leaving the game).
func stop_all() -> void:
	for voice in _world_voices:
		voice.stop()
	for voice in _flat_voices:
		voice.stop()
	for player in _music:
		player.stop()
	_ambience.stop()
	music_track = &""
	ambience_track = &""
	_last_played.clear()


## Whether `cue` was played since the history was last cleared.
func played(cue: StringName) -> bool:
	return history.has(cue)


func _music_level(track: StringName) -> float:
	return SoundBank.TRACKS.get(track, -6.0) + (DUCK_DB if _ducked else 0.0)


func _set_bus_volume(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))


## A random file of `cue`, never the same one twice running when it has more.
func _pick(cue: StringName) -> AudioStream:
	if not _streams.has(cue):
		var loaded: Array[AudioStream] = []
		for path in SoundFiles.FILES[cue]:
			var stream := load(path) as AudioStream
			if stream:
				loaded.append(stream)
		_streams[cue] = loaded
	var streams: Array = _streams[cue]
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	var index := _rng.randi_range(0, streams.size() - 2)
	var stream: AudioStream = streams[index]
	# Move the chosen one to the end, out of the next draw.
	streams.remove_at(index)
	streams.append(stream)
	return stream


func _looping(track: StringName) -> AudioStream:
	var stream := _pick(track)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func _make_buses() -> void:
	_add_bus(&"Sfx", &"Master")
	_add_bus(SoundBank.MUSIC, &"Master")
	_add_bus(SoundBank.WORLD, &"Sfx")
	_add_bus(SoundBank.UI, &"Sfx")
	_add_bus(SoundBank.AMBIENCE, &"Sfx")
	var world := AudioServer.get_bus_index(SoundBank.WORLD)
	# Combat is dense: the world sits below the interface and the music.
	AudioServer.set_bus_volume_db(world, WORLD_TRIM_DB)
	if AudioServer.get_bus_effect_count(world) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.55
		reverb.damping = 0.6
		reverb.wet = 0.12
		reverb.dry = 1.0
		AudioServer.add_bus_effect(world, reverb)
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, MASTER_TRIM_DB)
	if AudioServer.get_bus_effect_count(master) == 0:
		# Many blows at once must never clip.
		AudioServer.add_bus_effect(master, AudioEffectHardLimiter.new())


func _add_bus(bus: StringName, send: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, send)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_on_button_pressed.bind(node))


func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.has_meta(&"silent"):
		play(button.get_meta(&"sound", &"ui_click"))
