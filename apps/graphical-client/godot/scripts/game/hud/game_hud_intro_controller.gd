class_name GameHudIntroController
extends Node

const LOGO_HOLD_SECONDS: float = 2
const LOGO_FADE_SECONDS: float = 1.0
const TOP_BAR_FADE_SECONDS: float = 1.0

@export var top_bar: Control
@export var players_list: Control
@export var event_log: Control
@export var initial_logo: Control

var _intro_tween: Tween
var _has_played: bool = false

func _ready() -> void:
    assert(top_bar)
    assert(players_list)
    assert(event_log)
    assert(initial_logo)
    _configure_initial_state()
    call_deferred("play_intro")

func play_intro() -> void:
    if _has_played:
        return
    _has_played = true

    if _intro_tween != null and _intro_tween.is_running():
        _intro_tween.kill()

    _configure_initial_state()

    _intro_tween = create_tween()
    _intro_tween.set_trans(Tween.TRANS_CUBIC)
    _intro_tween.set_ease(Tween.EASE_IN_OUT)
    _intro_tween.tween_interval(LOGO_HOLD_SECONDS)
    _intro_tween.tween_method(_set_control_alpha.bind(initial_logo), initial_logo.modulate.a, 0.0, LOGO_FADE_SECONDS)
    _intro_tween.tween_callback(_hide_control.bind(initial_logo))
    _intro_tween.tween_callback(_show_control.bind(top_bar))
    _intro_tween.tween_callback(_show_control.bind(players_list))
    _intro_tween.tween_callback(_show_control.bind(event_log))
    _intro_tween.set_parallel(true)
    _intro_tween.tween_method(_set_control_alpha.bind(top_bar), top_bar.modulate.a, 1.0, TOP_BAR_FADE_SECONDS)
    _intro_tween.tween_method(_set_control_alpha.bind(players_list), players_list.modulate.a, 1.0, TOP_BAR_FADE_SECONDS)
    _intro_tween.tween_method(_set_control_alpha.bind(event_log), event_log.modulate.a, 1.0, TOP_BAR_FADE_SECONDS)

func _configure_initial_state() -> void:
    _show_control(initial_logo)
    _set_control_alpha(1.0, initial_logo)
    _show_control(top_bar)
    _set_control_alpha(0.0, top_bar)
    _show_control(players_list)
    _set_control_alpha(0.0, players_list)
    _show_control(event_log)
    _set_control_alpha(0.0, event_log)

func _show_control(target: Control) -> void:
    target.visible = true

func _hide_control(target: Control) -> void:
    target.visible = false

func _set_control_alpha(alpha_value: float, target: Control) -> void:
    var current_modulate: Color = target.modulate
    target.modulate = Color(current_modulate.r, current_modulate.g, current_modulate.b, alpha_value)
