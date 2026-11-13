extends SceneTree
## Saves the APPRENDISTA as a scene of the editor (game/apprendista.tscn):
## skeleton, skinned meshes with their weights, eyes, flame, cape. Built by
## game/devil.gd from art/apprendista; after this the scene is the source and
## can be retouched in Godot (bones, polygons, weights painted by hand).
##   godot --headless --path . -s tools/salva_scena.gd
## Careful: running it again overwrites the retouches made in the editor.

var d: Devil


func _initialize() -> void:
	d = (load("res://game/devil.gd") as GDScript).new()
	d.name = "Apprendista"
	root.add_child(d)


## the first frame: the devil is built (cape_setup ran with the default knobs,
## 1, 1, 0, so the cape's polygon is the drawing)
func _process(_delta: float) -> bool:
	own(d, d)
	var scene := PackedScene.new()
	var err := scene.pack(d)
	if err == OK:
		err = ResourceSaver.save(scene, Devil.SCENE)
	print("salvata " + Devil.SCENE if err == OK else "errore %d" % err)
	quit(0 if err == OK else 1)
	return true


func own(n: Node, owner_node: Node) -> void:
	for c in n.get_children():
		c.owner = owner_node
		own(c, owner_node)
