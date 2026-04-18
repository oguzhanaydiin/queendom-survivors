class_name EnchantedForest
extends BaseMap

const TILE_GRASS      = 0
const TILE_DARK_GRASS = 1
const TILE_STONE      = 2
const TILE_FLOWER     = 3

const TILE_SIZE   = 64  # px
const CHUNK_SIZE  = 16  # tiles per chunk
const RENDER_DIST = 3   # chunks around player

const _CHEST_SCENE: PackedScene = preload("res://scenes/chest/chest.tscn")

@onready var _tile_map: TileMapLayer = $TileMapLayer

var _noise: FastNoiseLite
var _generated_chunks: Dictionary = {}
var _player: Node2D
var _last_player_chunk := Vector2i(0x7FFFFFFF, 0x7FFFFFFF)


func _ready() -> void:
	_setup_noise()
	_build_tileset()


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.seed = 42
	_noise.frequency = 0.04


# called by World after player is in the scene tree
func initialize(player_node: Node2D) -> void:
	_player = player_node
	_generate_chunks_around(_player_chunk())


func _process(_delta: float) -> void:
	if not _player:
		return
	_stream_chunks()


func get_display_name() -> String:
	return "Enchanted Forest"


func _stream_chunks() -> void:
	var pc := _player_chunk()
	if pc == _last_player_chunk:
		return
	_last_player_chunk = pc
	for cx in range(pc.x - RENDER_DIST, pc.x + RENDER_DIST + 1):
		for cy in range(pc.y - RENDER_DIST, pc.y + RENDER_DIST + 1):
			var key := Vector2i(cx, cy)
			if not _generated_chunks.has(key):
				_generate_chunk(key)


func _generate_chunks_around(center: Vector2i) -> void:
	for cx in range(center.x - RENDER_DIST, center.x + RENDER_DIST + 1):
		for cy in range(center.y - RENDER_DIST, center.y + RENDER_DIST + 1):
			_generate_chunk(Vector2i(cx, cy))


func _generate_chunk(chunk_coord: Vector2i) -> void:
	_generated_chunks[chunk_coord] = true
	var origin := chunk_coord * CHUNK_SIZE
	for tx in range(CHUNK_SIZE):
		for ty in range(CHUNK_SIZE):
			var wtx := origin.x + tx
			var wty := origin.y + ty
			var tile_id := _tile_for_noise(_noise.get_noise_2d(wtx, wty))
			_tile_map.set_cell(Vector2i(wtx, wty), tile_id, Vector2i(0, 0))

	_spawn_chests_for_chunk(chunk_coord, origin)


func _spawn_chests_for_chunk(chunk_coord: Vector2i, origin: Vector2i) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(chunk_coord)) & 0x7FFFFFFF
	# ~26% of new chunks: was two low gates (~5%) so chests were too rare while exploring.
	if rng.randf() > 0.74:
		return
	var wx := origin.x + rng.randi_range(2, CHUNK_SIZE - 3)
	var wy := origin.y + rng.randi_range(2, CHUNK_SIZE - 3)
	var chest := _CHEST_SCENE.instantiate()
	chest.global_position = Vector2(
		float(wx) * TILE_SIZE + TILE_SIZE * 0.5,
		float(wy) * TILE_SIZE + TILE_SIZE * 0.5
	)
	scene.add_child(chest)


func _player_chunk() -> Vector2i:
	var tp := Vector2i(
		int(floor(_player.global_position.x / TILE_SIZE)),
		int(floor(_player.global_position.y / TILE_SIZE))
	)
	return Vector2i(
		int(floor(float(tp.x) / CHUNK_SIZE)),
		int(floor(float(tp.y) / CHUNK_SIZE))
	)


func _tile_for_noise(v: float) -> int:
	# noise range is [-1, 1]
	if v < -0.35:
		return TILE_DARK_GRASS
	elif v < 0.45:
		return TILE_GRASS
	elif v < 0.72:
		return TILE_STONE
	else:
		return TILE_FLOWER


# placeholder art - swap textures later
func _build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	var palette := {
		TILE_GRASS:      Color(0.32, 0.62, 0.22),
		TILE_DARK_GRASS: Color(0.20, 0.46, 0.13),
		TILE_STONE:      Color(0.53, 0.53, 0.50),
		TILE_FLOWER:     Color(0.38, 0.68, 0.28),
	}

	for tile_id in palette:
		var src := TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(_make_tile_image(tile_id, palette[tile_id]))
		src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		src.create_tile(Vector2i(0, 0))
		ts.add_source(src, tile_id)

	_tile_map.tile_set = ts


func _make_tile_image(tile_id: int, base: Color) -> Image:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(base)

	var rng := RandomNumberGenerator.new()
	rng.seed = tile_id * 99991 + 7
	for _i in range(60):
		var px := rng.randi_range(0, TILE_SIZE - 1)
		var py := rng.randi_range(0, TILE_SIZE - 1)
		img.set_pixel(px, py, base.lightened(rng.randf_range(-0.07, 0.07)))

	# grass tufts on grass tiles
	if tile_id == TILE_GRASS or tile_id == TILE_DARK_GRASS:
		var tuft_count := 5 if tile_id == TILE_GRASS else 3
		for _t in range(tuft_count):
			var tx := rng.randi_range(4, TILE_SIZE - 5)
			var ty := rng.randi_range(10, TILE_SIZE - 4)
			var blade_count := rng.randi_range(2, 4)
			for b in range(blade_count):
				var bx    := tx + b * 2
				var height := rng.randi_range(4, 8)
				var lean   := rng.randi_range(-1, 1)
				for h in range(height):
					var progress := float(h) / float(height)
					var col := base.darkened(0.18 - progress * 0.14)
					var x := clampi(bx + int(lean * progress * 2), 0, TILE_SIZE - 1)
					var y := clampi(ty - h, 0, TILE_SIZE - 1)
					img.set_pixel(x, y, col)

	# flower dots
	if tile_id == TILE_FLOWER:
		var accents := [Color(0.90, 0.30, 0.70), Color(0.95, 0.85, 0.20), Color(0.85, 0.30, 0.35)]
		for i in range(3):
			var cx := 10 + i * 20
			var cy := rng.randi_range(10, 22)
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					if dx * dx + dy * dy <= 4:
						img.set_pixel(
							clampi(cx + dx, 0, TILE_SIZE - 1),
							clampi(cy + dy, 0, TILE_SIZE - 1),
							accents[i]
						)

	return img
