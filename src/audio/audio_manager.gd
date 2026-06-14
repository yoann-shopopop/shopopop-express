class_name AudioManager
extends Node
## Tiny sound layer: a pool of SFX voices (so sounds overlap) plus a looping ambient music track. The
## clips are the procedurally-generated WAVs in assets/audio/ (see tools/generate_audio.gd). Exposed as
## static helpers backed by a single live instance, so any node can call [code]AudioManager.sfx(&"dice")[/code]
## without an autoload entry. [Main] creates one at startup. Mute toggles the Master bus.

const DIR := "res://assets/audio/"
const SFX_NAMES := [
	&"ui_click", &"dice", &"place", &"reserve", &"pickup",
	&"deliver", &"event", &"power", &"victory",
]
const SFX_VOICES := 8
const MUSIC_DB := -16.0   # ambient sits well under the SFX
const SFX_DB := -6.0

static var _instance: AudioManager

var _streams: Dictionary = {}            # StringName -> AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _muted := false


func _ready() -> void:
	_instance = self
	for n in SFX_NAMES:
		var path: String = DIR + String(n) + ".wav"
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for _i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"Master"
		add_child(voice)
		_voices.append(voice)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Master"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_start_music()


func _start_music() -> void:
	var path := DIR + "ambient.wav"
	if not ResourceLoader.exists(path):
		return
	var stream := load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono -> 2 bytes per frame
	_music.stream = stream
	_music.play()


## Plays the SFX named [param name] on the next free voice. No-op if audio isn't ready or unknown.
static func sfx(name: StringName, volume_db: float = SFX_DB) -> void:
	if _instance != null:
		_instance._play_sfx(name, volume_db)


func _play_sfx(name: StringName, volume_db: float) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.play()


## Toggles mute on the Master bus and returns the new muted state.
static func toggle_mute() -> bool:
	if _instance == null:
		return false
	_instance._muted = not _instance._muted
	AudioServer.set_bus_mute(0, _instance._muted)
	return _instance._muted


## Whether sound is currently muted.
static func is_muted() -> bool:
	return _instance != null and _instance._muted
