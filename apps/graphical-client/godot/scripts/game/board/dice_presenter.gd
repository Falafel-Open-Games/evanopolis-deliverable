class_name DicePresenter
extends Node

const DIE_ROLL_DURATION_SECONDS: float = 0.5
const DIE_ROLL_STAGGER_SECONDS: float = 0.1
const DIE_HOP_HEIGHT: float = 0.75
const DIE_EXTRA_SPINS: float = 2.0
const DIE_SPIN_AXIS: Vector3 = Vector3(1.0, 0.35, 0.75)
const POST_ROLL_PAUSE_SECONDS: float = 0.7

signal presentation_finished(die_1: int, die_2: int)

var _die_a: Node3D = null
var _die_b: Node3D = null
var _die_a_rest_transform: Transform3D = Transform3D.IDENTITY
var _die_b_rest_transform: Transform3D = Transform3D.IDENTITY
var _basis_for_face_up_callback: Callable
var _dice_roll_tween: Tween = null
var _presenting_die_1: int = -1
var _presenting_die_2: int = -1

func configure(die_a: Node3D, die_b: Node3D, basis_for_face_up_callback: Callable) -> void:
    assert(die_a != null)
    assert(die_b != null)
    assert(basis_for_face_up_callback.is_valid())
    _die_a = die_a
    _die_b = die_b
    _die_a_rest_transform = die_a.transform
    _die_b_rest_transform = die_b.transform
    _basis_for_face_up_callback = basis_for_face_up_callback

func set_dice_values(die_1: int, die_2: int) -> void:
    assert(_die_a != null)
    assert(_die_b != null)
    if _dice_roll_tween != null and die_1 == _presenting_die_1 and die_2 == _presenting_die_2:
        return
    cancel_presentation()
    _die_a.basis = _basis_for_face_up_callback.call(die_1)
    _die_b.basis = _basis_for_face_up_callback.call(die_2)
    _die_a.transform = Transform3D(_die_a.basis, _die_a_rest_transform.origin)
    _die_b.transform = Transform3D(_die_b.basis, _die_b_rest_transform.origin)

func present_dice_roll(die_1: int, die_2: int) -> void:
    assert(_die_a != null)
    assert(_die_b != null)
    cancel_presentation()
    _presenting_die_1 = die_1
    _presenting_die_2 = die_2
    var from_basis_a: Basis = _die_a.basis
    var from_basis_b: Basis = _die_b.basis
    var to_basis_a: Basis = _basis_for_face_up_callback.call(die_1)
    var to_basis_b: Basis = _basis_for_face_up_callback.call(die_2)
    var total_duration_seconds: float = DIE_ROLL_DURATION_SECONDS + DIE_ROLL_STAGGER_SECONDS
    _dice_roll_tween = create_tween()
    _dice_roll_tween.tween_method(
        _set_dice_roll_presentation.bind(from_basis_a, to_basis_a, from_basis_b, to_basis_b),
        0.0,
        1.0,
        total_duration_seconds
    )
    _dice_roll_tween.finished.connect(_on_dice_roll_presentation_finished.bind(die_1, die_2))

func is_presenting() -> bool:
    return _dice_roll_tween != null

func cancel_presentation() -> void:
    if _dice_roll_tween == null:
        return
    if _dice_roll_tween.is_running():
        _dice_roll_tween.kill()
    _dice_roll_tween = null
    _presenting_die_1 = -1
    _presenting_die_2 = -1

func _set_dice_roll_presentation(
    progress: float,
    from_basis_a: Basis,
    to_basis_a: Basis,
    from_basis_b: Basis,
    to_basis_b: Basis
) -> void:
    var total_duration_seconds: float = DIE_ROLL_DURATION_SECONDS + DIE_ROLL_STAGGER_SECONDS
    var elapsed_seconds: float = clampf(progress, 0.0, 1.0) * total_duration_seconds
    var die_a_progress: float = clampf(elapsed_seconds / DIE_ROLL_DURATION_SECONDS, 0.0, 1.0)
    var die_b_progress: float = clampf(
        (elapsed_seconds - DIE_ROLL_STAGGER_SECONDS) / DIE_ROLL_DURATION_SECONDS,
        0.0,
        1.0
    )
    _set_die_roll_pose(_die_a, _die_a_rest_transform, die_a_progress, from_basis_a, to_basis_a)
    _set_die_roll_pose(_die_b, _die_b_rest_transform, die_b_progress, from_basis_b, to_basis_b)

func _set_die_roll_pose(
    die_node: Node3D,
    rest_transform: Transform3D,
    progress: float,
    from_basis: Basis,
    to_basis: Basis
) -> void:
    var clamped_progress: float = clampf(progress, 0.0, 1.0)
    var hop_offset: float = sin(clamped_progress * PI) * DIE_HOP_HEIGHT
    var spin_basis: Basis = Basis(DIE_SPIN_AXIS.normalized(), TAU * DIE_EXTRA_SPINS * clamped_progress)
    var oriented_basis: Basis = from_basis.slerp(to_basis, clamped_progress) * spin_basis
    die_node.transform = Transform3D(
        oriented_basis,
        rest_transform.origin + Vector3.UP * hop_offset
    )

func _on_dice_roll_presentation_finished(die_1: int, die_2: int) -> void:
    _dice_roll_tween = null
    _presenting_die_1 = -1
    _presenting_die_2 = -1
    _die_a.basis = _basis_for_face_up_callback.call(die_1)
    _die_b.basis = _basis_for_face_up_callback.call(die_2)
    _die_a.transform = Transform3D(_die_a.basis, _die_a_rest_transform.origin)
    _die_b.transform = Transform3D(_die_b.basis, _die_b_rest_transform.origin)
    if POST_ROLL_PAUSE_SECONDS > 0.0:
        var pause_tween: Tween = create_tween()
        pause_tween.tween_interval(POST_ROLL_PAUSE_SECONDS)
        pause_tween.finished.connect(func() -> void:
            presentation_finished.emit(die_1, die_2)
        )
        return
    presentation_finished.emit(die_1, die_2)
