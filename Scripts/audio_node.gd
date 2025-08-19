extends Node3D

# --- Node References ---
@onready var input: AudioStreamPlayer3D = $Input
@onready var output: AudioStreamPlayer3D = $Output
@onready var player = $"../"

# --- Exported Properties ---
@export var outputPath: NodePath

# --- Audio Capture ---
var mic_capture: AudioEffectOpusChunked
var playback

# --- Networking Stats ---
var packets_received: int = 0
var packets_sent: int = 0

# --- Timing ---
var tick: float = 0.0

# --- Thresholds ---
var inputThreshold: float = 0.004

# --- Internal References ---
var index
var effect

# ---------------------------------------------------------
# Audio Setup
# ---------------------------------------------------------
func setupAudio(id):
	set_multiplayer_authority(id)

	if player.is_multiplayer_authority():
		print(get_path())
		# Set up microphone input
		input.stream = AudioStreamMicrophone.new()
		input.bus = "Record"  # Make sure this is explicitly set!
		input.play()

		# Configure capture settings
		index = AudioServer.get_bus_index("Record")
		
		mic_capture = AudioServer.get_bus_effect(index, 0)
		_configure_mic_capture()
		
		# Remove output for local player
		output.queue_free()
	else:
		# Remove input for listeners
		input.queue_free()

		# Start playback
		get_node(outputPath).play()
		
		await get_tree().process_frame
		playback = get_node(outputPath).get_stream_playback()

# Configure Opus microphone settings
func _configure_mic_capture():
	mic_capture.audiosamplerate = 48000    # Match input to Opus rate
	mic_capture.opusbitrate = 24000        # Try 8000–32000; higher = better
	mic_capture.opusframesize = 960        # Match frame size
	mic_capture.audiosamplesize = 960      # Higher = better quality (0–10)
	mic_capture.opuscomplexity = 8         # Keep this for voice

# ---------------------------------------------------------
# Processing
# ---------------------------------------------------------
func _process(delta: float) -> void:
	if player.is_multiplayer_authority():
		tick += delta
		if tick >= 0.01:
			processMic()
			tick = 0.0

# Capture mic data and send over network
func processMic():
	while mic_capture.chunk_available():
		# Get raw audio data (uncompressed float32 samples)
		var packet: PackedByteArray = mic_capture.read_opus_packet(PackedByteArray())
		var raw_chunk: PackedVector2Array = mic_capture.read_chunk(false) 

		# Drop the chunk from buffer so it doesn't pile up
		mic_capture.drop_chunk()
#
		# Convert stereo to mono if needed (by averaging channels)
		var mono_samples := PackedFloat32Array()
		mono_samples.resize(raw_chunk.size())
		for i in range(raw_chunk.size()):
			mono_samples[i] = (raw_chunk[i].x + raw_chunk[i].y) * 0.5
#
		#print("Check Voice")
		# Check loudness before sending
		if _is_voice_active(mono_samples):
			#print("Voice loud enough to send")
			if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and packet.size() > 0:
				_voice_packet_received.rpc(packet, str(get_path()))
				packets_sent += 1
				if packets_sent % 100 == 0:
					print("Packets sent: ", packets_sent, " from id ", multiplayer.get_unique_id())

# --- Simple amplitude check for VAD ---
func _is_voice_active(samples: PackedFloat32Array) -> bool:
	if samples.is_empty():
		return false

	# Calculate RMS (Root Mean Square) amplitude
	var sum_sq: float = 0.0
	for sample in samples:
		sum_sq += sample * sample
	var rms = sqrt(sum_sq / samples.size())

	return rms >= inputThreshold

# ---------------------------------------------------------
# Networking
# ---------------------------------------------------------
@rpc("any_peer", "unreliable")
func _voice_packet_received(packet, path):
	packets_received += 1

	if packets_received % 100 == 0:
		print(output.get_path())
		print("Packets received: ", packets_received, " at id ", multiplayer.get_unique_id())

	output.stream.push_opus_packet(packet, 0, 0)
