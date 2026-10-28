extends Node3D

const WORLD_RADIUS := 180.0
const SAVE_PATH := "user://forest_survival_save.json"

var player: CharacterBody3D
var camera: Camera3D
var ui_label: Label
var message_label: Label
var inventory_label: Label
var touch_pad: Control
var touch_move := Vector2.ZERO
var hp := 100.0
var hunger := 100.0
var thirst := 100.0
var stamina := 100.0
var day_time := 0.25
var wood := 0
var stone := 0
var berries := 2
var meat := 0
var has_axe := false
var has_bow := false
var arrows := 0
var built_shelters := 0
var message_timer := 0.0
var nearby_resource: Node3D
var resource_nodes: Array[Node3D] = []
var animal_nodes: Array[Node3D] = []
var yaw := 0.0
var pitch := -0.22
var look_touch_id := -1
var last_touch := Vector2.ZERO

func _ready() -> void:
    randomize()
    _setup_world()
    _setup_player()
    _setup_ui()
    _load_game()
    _say("Выживание началось. Собирай ресурсы: подойди к дереву или камню и нажми E.")
    set_process(true)
    set_physics_process(true)

func _setup_world() -> void:
    var env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.72, 0.78, 0.85)
    environment.ambient_light_energy = 0.65
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = environment
    add_child(env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -30, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    var ground := StaticBody3D.new()
    ground.name = "ForestGround"
    var mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(WORLD_RADIUS * 2.0, WORLD_RADIUS * 2.0)
    mesh.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.18, 0.30, 0.13)
    mat.roughness = 1.0
    mesh.material_override = mat
    ground.add_child(mesh)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(WORLD_RADIUS * 2.0, 1.0, WORLD_RADIUS * 2.0)
    col.shape = shape
    col.position.y = -0.5
    ground.add_child(col)
    add_child(ground)

    # Procedurally scatter trees and stones; keep a clearing around the spawn point.
    for i in range(240):
        var p := _random_ground_position(14.0)
        _make_tree(p)
    for i in range(85):
        var p := _random_ground_position(7.0)
        _make_stone(p)
    for i in range(22):
        var p := _random_ground_position(12.0)
        _make_resource_berry(p)
    for i in range(10):
        var p := _random_ground_position(20.0)
        _make_animal(p, i % 3 == 0)

func _random_ground_position(clear_radius: float) -> Vector3:
    var p := Vector3(randf_range(-WORLD_RADIUS + 8, WORLD_RADIUS - 8), 0, randf_range(-WORLD_RADIUS + 8, WORLD_RADIUS - 8))
    if Vector2(p.x, p.z).length() < clear_radius:
        p.x += clear_radius * 1.5
    return p

func _make_tree(pos: Vector3) -> void:
    var root := StaticBody3D.new()
    root.position = pos
    root.set_meta("resource_type", "tree")
    var trunk := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.22
    cylinder.bottom_radius = 0.38
    cylinder.height = randf_range(3.0, 4.5)
    trunk.mesh = cylinder
    trunk.position.y = cylinder.height / 2
    var bark := StandardMaterial3D.new()
    bark.albedo_color = Color(0.25, 0.15, 0.08)
    trunk.material_override = bark
    root.add_child(trunk)
    var crown := MeshInstance3D.new()
    var cone := SphereMesh.new()
    cone.radius = randf_range(1.2, 1.8)
    cone.height = cone.radius * 2.0
    crown.mesh = cone
    crown.position.y = cylinder.height + 0.8
    var leaves := StandardMaterial3D.new()
    leaves.albedo_color = [Color(0.08,0.23,0.08), Color(0.12,0.30,0.10), Color(0.16,0.34,0.12)].pick_random()
    crown.material_override = leaves
    root.add_child(crown)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 0.45
    shape.height = cylinder.height
    collision.shape = shape
    collision.position.y = cylinder.height / 2
    root.add_child(collision)
    add_child(root)
    resource_nodes.append(root)

func _make_stone(pos: Vector3) -> void:
    var root := StaticBody3D.new()
    root.position = pos
    root.set_meta("resource_type", "stone")
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = randf_range(0.35, 0.75)
    sphere.height = sphere.radius * 1.5
    mesh.mesh = sphere
    mesh.position.y = sphere.radius * 0.55
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.32, 0.34, 0.32)
    mesh.material_override = mat
    root.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = sphere.radius
    collision.shape = shape
    collision.position.y = sphere.radius * 0.55
    root.add_child(collision)
    add_child(root)
    resource_nodes.append(root)

func _make_resource_berry(pos: Vector3) -> void:
    var root := StaticBody3D.new()
    root.position = pos
    root.set_meta("resource_type", "berries")
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.38
    sphere.height = 0.55
    mesh.mesh = sphere
    mesh.position.y = 0.35
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.48, 0.12)
    mesh.material_override = mat
    root.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.55
    collision.shape = shape
    collision.position.y = 0.35
    root.add_child(collision)
    add_child(root)
    resource_nodes.append(root)

func _make_animal(pos: Vector3, predator: bool) -> void:
    var animal := CharacterBody3D.new()
    animal.position = pos
    animal.set_meta("predator", predator)
    animal.set_meta("hp", 45.0 if predator else 30.0)
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.45 if predator else 0.36
    mesh.height = 1.2 if predator else 0.95
    body.mesh = mesh
    body.position.y = 0.62
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.28, 0.24, 0.20) if predator else Color(0.48, 0.36, 0.20)
    body.material_override = mat
    animal.add_child(body)
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = mesh.radius
    shape.height = mesh.height
    col.shape = shape
    col.position.y = 0.62
    animal.add_child(col)
    add_child(animal)
    animal_nodes.append(animal)

func _setup_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0, 1.2, 0)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.38
    capsule.height = 1.75
    body.mesh = capsule
    body.position.y = 0.88
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.30, 0.36)
    body.material_override = mat
    player.add_child(body)
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.38
    shape.height = 1.75
    col.shape = shape
    col.position.y = 0.88
    player.add_child(col)
    add_child(player)

    var pivot := Node3D.new()
    pivot.name = "CameraPivot"
    pivot.position.y = 1.45
    player.add_child(pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 1.0, 5.5)
    camera.rotation_degrees.x = -10
    camera.current = true
    pivot.add_child(camera)
    camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)

func _setup_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(16, 16)
    panel.custom_minimum_size = Vector2(310, 130)
    layer.add_child(panel)
    ui_label = Label.new()
    ui_label.add_theme_font_size_override("font_size", 18)
    panel.add_child(ui_label)

    var inv_panel := PanelContainer.new()
    inv_panel.position = Vector2(16, 158)
    inv_panel.custom_minimum_size = Vector2(310, 95)
    layer.add_child(inv_panel)
    inventory_label = Label.new()
    inventory_label.add_theme_font_size_override("font_size", 16)
    inv_panel.add_child(inventory_label)

    message_label = Label.new()
    message_label.position = Vector2(350, 20)
    message_label.size = Vector2(600, 45)
    message_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(message_label)

    var buttons := [
        ["Взаимодействовать / E", Vector2(-230, -135), "interact"],
        ["Удар / ЛКМ", Vector2(-230, -80), "attack"],
        ["Крафт: топор", Vector2(-230, -25), "axe"],
        ["Крафт: лук", Vector2(-230, 30), "bow"],
        ["Построить укрытие", Vector2(-230, 85), "shelter"],
        ["Еда / ягоды", Vector2(-230, 140), "eat"],
        ["Сохранить", Vector2(-230, 195), "save"]
    ]
    var viewport_size := get_viewport().get_visible_rect().size
    for i in range(buttons.size()):
        var item = buttons[i]
        var b := Button.new()
        b.text = item[0]
        var column := i % 2
        var row := int(i / 2)
        b.position = Vector2(viewport_size.x - 470 + column * 230, viewport_size.y - 218 + row * 52)
        b.size = Vector2(220, 46)
        b.pressed.connect(_on_action.bind(item[2]))
        layer.add_child(b)

    var controls := Label.new()
    controls.text = "WASD: движение | Shift: бег | E: собрать | ЛКМ: атака\nНа телефоне: кнопки справа, движение клавиатурой/геймпадом"
    controls.position = Vector2(16, get_viewport().get_visible_rect().size.y - 58)
    controls.add_theme_font_size_override("font_size", 14)
    layer.add_child(controls)

func _on_action(action: String) -> void:
    match action:
        "interact": _interact()
        "attack": _attack()
        "axe": _craft_axe()
        "bow": _craft_bow()
        "shelter": _build_shelter()
        "eat": _eat_berries()
        "save": _save_game()

func _physics_process(delta: float) -> void:
    if player == null:
        return
    day_time = fposmod(day_time + delta / 480.0, 1.0)
    hunger = maxf(0.0, hunger - delta * 0.045)
    thirst = maxf(0.0, thirst - delta * 0.07)
    stamina = minf(100.0, stamina + delta * 5.0)
    if hunger <= 0 or thirst <= 0:
        hp = maxf(0.0, hp - delta * 1.2)
    if hp <= 0:
        _say("Ты потерял сознание. Нажми «Сохранить» не поможет — начни заново.")
        hp = 100
        hunger = 65
        thirst = 65
        player.position = Vector3(0, 1.2, 0)

    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (player.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed := 7.0 if Input.is_action_pressed("sprint") and stamina > 3 else 4.2
    if speed > 4.2 and direction.length() > 0.1:
        stamina = maxf(0, stamina - delta * 16.0)
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    if not player.is_on_floor():
        player.velocity.y -= 20.0 * delta
    else:
        player.velocity.y = 0
    player.move_and_slide()
    if direction.length() > 0.1:
        player.rotation.y = atan2(-direction.x, -direction.z)

    # Simple wandering and predator pressure when close.
    for animal in animal_nodes:
        if not is_instance_valid(animal):
            continue
        if animal.get_meta("predator", false):
            var d := animal.global_position.distance_to(player.global_position)
            if d < 2.2:
                hp = maxf(0.0, hp - delta * 5.0)
                if randf() < 0.02:
                    _say("Волк атакует! Отойди или отбивайся.")
        elif randf() < 0.006:
            animal.rotation.y += randf_range(-1.0, 1.0) * delta * 10.0

    if message_timer > 0:
        message_timer -= delta
        if message_timer <= 0:
            message_label.text = ""
    _update_ui()

func _process(_delta: float) -> void:
    # Camera follows player and keeps a third-person view.
    if player and camera:
        var pivot := player.get_node("CameraPivot") as Node3D
        pivot.rotation.y = yaw
        pivot.rotation.x = pitch
        camera.position = Vector3(0, 0.8, 5.8)
        camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        yaw -= event.relative.x * 0.005
        pitch = clampf(pitch - event.relative.y * 0.004, -0.85, 0.35)
    if event is InputEventKey and event.pressed and event.keycode == KEY_E:
        _interact()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _attack()

func _interact() -> void:
    var best: Node3D = null
    var best_dist := 3.4
    for node in resource_nodes:
        if not is_instance_valid(node):
            continue
        var d := node.global_position.distance_to(player.global_position)
        if d < best_dist:
            best = node
            best_dist = d
    if best == null:
        _say("Рядом нет ресурсов. Подойди ближе к дереву, камню или кусту.")
        return
    var kind: String = best.get_meta("resource_type", "")
    match kind:
        "tree":
            wood += randi_range(2, 4) if has_axe else 1
            _say("Собрана древесина: +" + str(3 if has_axe else 1))
        "stone":
            stone += randi_range(1, 3)
            _say("Ты подобрал камни.")
        "berries":
            berries += randi_range(2, 4)
            _say("Собраны ягоды.")
    resource_nodes.erase(best)
    best.queue_free()

func _attack() -> void:
    var target: Node3D = null
    var dist := 3.0
    for animal in animal_nodes:
        if not is_instance_valid(animal):
            continue
        var d := animal.global_position.distance_to(player.global_position)
        if d < dist:
            target = animal
            dist = d
    if target == null:
        _say("Никого рядом нет.")
        return
    var damage := 18.0 if has_axe else 7.0
    target.set_meta("hp", float(target.get_meta("hp", 30.0)) - damage)
    _say("Удар! Урон: " + str(int(damage)))
    if float(target.get_meta("hp", 0.0)) <= 0:
        if target.get_meta("predator", false):
            meat += 2
            _say("Хищник побеждён. Мясо +2.")
        else:
            meat += 2
            _say("Добыта дичь. Мясо +2.")
        animal_nodes.erase(target)
        target.queue_free()

func _craft_axe() -> void:
    if has_axe:
        _say("Топор уже создан.")
    elif wood >= 3 and stone >= 2:
        wood -= 3
        stone -= 2
        has_axe = true
        _say("Создан каменный топор. Теперь древесины больше.")
    else:
        _say("Для топора нужно 3 дерева и 2 камня.")

func _craft_bow() -> void:
    if has_bow:
        _say("Лук уже создан.")
    elif wood >= 5 and stone >= 1:
        wood -= 5
        stone -= 1
        has_bow = true
        arrows = 5
        _say("Создан лук и 5 стрел. (Дальний бой — базовая версия.)")
    else:
        _say("Для лука нужно 5 дерева и 1 камень.")

func _build_shelter() -> void:
    if wood < 8:
        _say("Для укрытия нужно 8 древесины.")
        return
    wood -= 8
    built_shelters += 1
    var shelter := Node3D.new()
    shelter.position = player.global_position + player.global_transform.basis.z * -3
    var box := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(3.0, 1.8, 2.5)
    box.mesh = mesh
    box.position.y = 0.9
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.30, 0.20, 0.11)
    box.material_override = mat
    shelter.add_child(box)
    add_child(shelter)
    _say("Укрытие построено. Всего: " + str(built_shelters))

func _eat_berries() -> void:
    if berries > 0:
        berries -= 1
        hunger = minf(100, hunger + 18)
        thirst = minf(100, thirst + 4)
        _say("Ты съел ягоды.")
    elif meat > 0:
        meat -= 1
        hunger = minf(100, hunger + 35)
        _say("Ты съел мясо.")
    else:
        _say("Нет еды. Найди ягоды или охоться.")

func _update_ui() -> void:
    var hour := int(day_time * 24.0)
    var phase := "День" if hour >= 6 and hour < 19 else "Ночь"
    ui_label.text = "ВЫЖИВАНИЕ  |  " + phase + " " + str(hour) + ":00\nЗдоровье: " + str(int(hp)) + "   Выносливость: " + str(int(stamina)) + "\nГолод: " + str(int(hunger)) + "   Жажда: " + str(int(thirst))
    inventory_label.text = "ИНВЕНТАРЬ\nДерево: %d   Камень: %d\nЯгоды: %d   Мясо: %d\nТопор: %s   Лук: %s" % [wood, stone, berries, meat, "да" if has_axe else "нет", "да" if has_bow else "нет"]

func _say(text: String) -> void:
    if message_label:
        message_label.text = text
        message_timer = 4.0

func _save_game() -> void:
    var data := {
        "position": [player.position.x, player.position.y, player.position.z],
        "hp": hp, "hunger": hunger, "thirst": thirst, "stamina": stamina,
        "wood": wood, "stone": stone, "berries": berries, "meat": meat,
        "has_axe": has_axe, "has_bow": has_bow, "arrows": arrows,
        "built_shelters": built_shelters, "day_time": day_time
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        _say("Игра сохранена на устройстве.")
    else:
        _say("Не удалось сохранить игру.")

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not file:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var data: Dictionary = parsed
    var p: Array = data.get("position", [0, 1.2, 0])
    player.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
    hp = float(data.get("hp", 100))
    hunger = float(data.get("hunger", 100))
    thirst = float(data.get("thirst", 100))
    stamina = float(data.get("stamina", 100))
    wood = int(data.get("wood", 0))
    stone = int(data.get("stone", 0))
    berries = int(data.get("berries", 2))
    meat = int(data.get("meat", 0))
    has_axe = bool(data.get("has_axe", false))
    has_bow = bool(data.get("has_bow", false))
    arrows = int(data.get("arrows", 0))
    built_shelters = int(data.get("built_shelters", 0))
    day_time = float(data.get("day_time", 0.25))
