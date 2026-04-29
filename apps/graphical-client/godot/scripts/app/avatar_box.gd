class_name AvatarBox
extends Control

const DEFAULT_ICON_ID: int = 11
const ICON_COLUMNS: int = 4
const ICON_ROWS: int = 4

@export var hexagon_texture: TextureRect
@export var icon_texture_rect: TextureRect

var _icon_texture_initialized: bool = false

func _ready() -> void:
    assert(hexagon_texture)
    assert(icon_texture_rect)
    _ensure_unique_icon_texture()

func set_icon_id(icon_id: int) -> void:
    _ensure_unique_icon_texture()
    AvatarBox.apply_icon_id_to_texture_rect(icon_texture_rect, icon_id)

func set_hexagon_modulate(color_value: Color) -> void:
    hexagon_texture.modulate = color_value

static func apply_icon_id_to_texture_rect(target: TextureRect, icon_id: int) -> void:
    assert(target)
    var atlas_texture: AtlasTexture = target.texture as AtlasTexture
    assert(atlas_texture)
    var atlas: Texture2D = atlas_texture.atlas
    assert(atlas)

    var icon_count: int = ICON_COLUMNS * ICON_ROWS
    var resolved_icon_id: int = icon_id
    if resolved_icon_id < 0 or resolved_icon_id >= icon_count:
        resolved_icon_id = DEFAULT_ICON_ID

    var icon_width: float = float(atlas.get_width()) / float(ICON_COLUMNS)
    var icon_height: float = float(atlas.get_height()) / float(ICON_ROWS)
    var icon_column: int = resolved_icon_id % ICON_COLUMNS
    @warning_ignore("integer_division")
    var icon_row: int = resolved_icon_id /ICON_COLUMNS
    atlas_texture.region = Rect2(
        Vector2(float(icon_column) * icon_width, float(icon_row) * icon_height),
        Vector2(icon_width, icon_height)
    )

func _ensure_unique_icon_texture() -> void:
    if _icon_texture_initialized:
        return
    var atlas_texture: AtlasTexture = icon_texture_rect.texture as AtlasTexture
    assert(atlas_texture)
    var duplicated_texture: AtlasTexture = atlas_texture.duplicate() as AtlasTexture
    assert(duplicated_texture)
    icon_texture_rect.texture = duplicated_texture
    _icon_texture_initialized = true
