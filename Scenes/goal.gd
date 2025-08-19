extends StaticBody3D

@export var isRed : bool

@onready var sandbox = $"../"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("ball") and sandbox.can_score:
		sandbox.can_score = false
		
		# True is give point to red, False is point to blue
		sandbox.add_score(isRed)
		sandbox.reset_ball()
