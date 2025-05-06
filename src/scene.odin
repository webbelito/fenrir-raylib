package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import raylib "vendor:raylib"

// Scene structure
Scene :: struct {
	name:     string,
	path:     string,

	// List of entities in the scene
	entities: [dynamic]Entity,

	// Is the scene loaded or not
	loaded:   bool,

	// Is this scene dirty (has unsaved changes)
	dirty:    bool,
}

// Current scene being edited/played
current_scene: Scene

// List of available scenes
available_scenes: [dynamic]string

// Scene file format for JSON serialization
Scene_Data :: struct {
	name:     string `json:"name"`,
	version:  string `json:"version"`,
	entities: [dynamic]Entity_Data `json:"entities"`,
}

Entity_Data :: struct {
	name:      string `json:"name"`,
	transform: Transform_Data `json:"transform"`,
	renderer:  Maybe(Renderer_Data) `json:"renderer,omitempty"`,
	camera:    Maybe(Camera_Data) `json:"camera,omitempty"`,
	light:     Maybe(Light_Data) `json:"light,omitempty"`,
	script:    Maybe(Script_Data) `json:"script,omitempty"`,
}

Transform_Data :: struct {
	position: [3]f32 `json:"position"`,
	rotation: [3]f32 `json:"rotation"`,
	scale:    [3]f32 `json:"scale"`,
}

Renderer_Data :: struct {
	mesh_path:     string `json:"mesh_path"`,
	material_path: string `json:"material_path"`,
}

Camera_Data :: struct {
	fov:     f32 `json:"fov"`,
	near:    f32 `json:"near"`,
	far:     f32 `json:"far"`,
	is_main: bool `json:"is_main"`,
}

Light_Data :: struct {
	light_type: string `json:"light_type"`,
	color:      [3]f32 `json:"color"`,
	intensity:  f32 `json:"intensity"`,
	range:      f32 `json:"range"`,
	spot_angle: f32 `json:"spot_angle"`,
}

Script_Data :: struct {
	script_name: string `json:"script_name"`,
}

// Initialize the scene system
scene_init :: proc() {
	log_info(.ENGINE, "Initializing scene system")

	// Initialize the current scene
	current_scene.name = "Untitled"
	current_scene.path = ""
	current_scene.entities = make([dynamic]Entity)
	current_scene.loaded = false
	current_scene.dirty = false

	// Initialize the available scenes list
	available_scenes = make([dynamic]string)

	// Scan for available scenes
	scene_scan_available_scenes()
}

// Shutdown the scene system
scene_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down scene system")

	// Unload the current scene if loaded
	if current_scene.loaded {
		scene_unload()
	}

	// Free resources
	delete(current_scene.entities)
	delete(available_scenes)
}

// Scan for available scenes in the assets/scenes directory
scene_scan_available_scenes :: proc() {
	scenes_dir := "assets/scenes"

	// Clear the available scenes list
	clear(&available_scenes)

	// Check if the directory exists
	if !os.exists(scenes_dir) {
		log_warning(.ENGINE, "Scenes directory '%s' does not exist", scenes_dir)
		return
	}

	// Open the directory
	dir, err := os.open(scenes_dir)
	if err != os.ERROR_NONE {
		log_error(.ENGINE, "Failed to open scenes directory: %v", err)
		return
	}
	defer os.close(dir)

	// Read directory entries
	entries, read_err := os.read_dir(dir, 0)
	if read_err != os.ERROR_NONE {
		log_error(.ENGINE, "Failed to read scenes directory: %v", read_err)
		return
	}
	defer os.file_info_slice_delete(entries)

	// Filter for .json files
	for entry in entries {
		if !entry.is_dir && strings.has_suffix(entry.name, ".json") {
			// Add to available scenes list
			scene_name := strings.clone(entry.name)
			append(&available_scenes, scene_name)
			log_debug(.ENGINE, "Found scene: %s", scene_name)
		}
	}

	log_info(.ENGINE, "Found %d scene(s)", len(available_scenes))
}

// Create a new scene
scene_new :: proc(name: string) -> bool {
	if current_scene.loaded && current_scene.dirty {
		log_warning(.ENGINE, "Current scene has unsaved changes")
		return false
	}

	// Unload current scene if loaded
	if current_scene.loaded {
		scene_unload()
	}

	// Initialize new scene
	current_scene.name = strings.clone(name)
	current_scene.path = ""
	current_scene.loaded = true
	current_scene.dirty = true

	// Create default entities
	root := ecs_create_entity()
	ecs_add_transform(root, {0, 0, 0}, {0, 0, 0}, {1, 1, 1})
	append(&current_scene.entities, root)

	// Create camera
	camera := ecs_create_entity()
	ecs_add_transform(camera, {0, 5, -10}, {0, 0, 0}, {1, 1, 1})
	ecs_add_camera(camera, 60.0, 0.1, 1000.0, true)
	append(&current_scene.entities, camera)

	// Create a test cube
	cube := ecs_create_entity()
	ecs_add_transform(cube, {0, 0, 0}, {0, 0, 0}, {1, 1, 1})
	ecs_add_renderer(cube, "cube", "default_material")
	append(&current_scene.entities, cube)

	log_info(.ENGINE, "Created new scene: %s", name)
	return true
}

// Load a scene from disk
scene_load :: proc(path: string) -> bool {
	if current_scene.loaded && current_scene.dirty {
		log_warning(.ENGINE, "Current scene has unsaved changes, forcing load anyway")
	}

	// Unload current scene if loaded
	if current_scene.loaded {
		scene_unload()
	}

	log_info(.ENGINE, "Loading scene from: %s", path)

	// Check if file exists
	if !os.exists(path) {
		log_error(.ENGINE, "Scene file does not exist: %s", path)
		return false
	}

	// Read file
	data_bytes, ok := os.read_entire_file(path)
	if !ok {
		log_error(.ENGINE, "Failed to read scene file: %s (Error: %v)", path, ok)
		return false
	}
	defer delete(data_bytes)

	log_info(.ENGINE, "Successfully read scene file, size: %d bytes", len(data_bytes))

	// Parse JSON
	scene_data: Scene_Data
	err := json.unmarshal(data_bytes, &scene_data)
	if err != nil {
		log_error(.ENGINE, "Failed to parse scene data: %v (Data: %s)", err, string(data_bytes))
		return false
	}

	log_info(
		.ENGINE,
		"Successfully parsed scene data: %s with %d entities",
		scene_data.name,
		len(scene_data.entities),
	)
	defer {
		for entity in scene_data.entities {
			delete(entity.name)
			if entity.renderer != nil {
				delete(entity.renderer.?.mesh_path)
				delete(entity.renderer.?.material_path)
			}
			if script, ok := entity.script.?; ok {
				delete(script.script_name)
			}
		}
		delete(scene_data.entities)
		delete(scene_data.name)
		delete(scene_data.version)
	}

	// Initialize new scene
	current_scene.name = strings.clone(scene_data.name)
	current_scene.path = strings.clone(path)
	current_scene.loaded = true
	current_scene.dirty = false

	// Create entities from data
	for entity_data in scene_data.entities {
		entity := create_entity_from_data(entity_data.transform)
		if entity == 0 {
			continue
		}

		// Add renderer
		if renderer_data, ok := entity_data.renderer.?; ok {
			renderer := ecs_add_renderer(entity)
			if renderer != nil {
				renderer.mesh = renderer_data.mesh_path
				renderer.material = renderer_data.material_path
			}
		}

		// Add camera
		if camera_data, ok := entity_data.camera.?; ok {
			camera := ecs_add_camera(entity)
			if camera != nil {
				camera.fov = camera_data.fov
				camera.near = camera_data.near
				camera.far = camera_data.far
				camera.is_main = camera_data.is_main
			}
		}

		// Add light
		if light_data, ok := entity_data.light.?; ok {
			light := ecs_add_light(entity)
			if light != nil {
				light.color = light_data.color
				light.intensity = light_data.intensity
				light.range = light_data.range
				light.spot_angle = light_data.spot_angle
				// Parse light type
				switch light_data.light_type {
				case "DIRECTIONAL":
					light.light_type = .DIRECTIONAL
				case "POINT":
					light.light_type = .POINT
				case "SPOT":
					light.light_type = .SPOT
				}
			}
		}

		// Add script
		if script_data, ok := entity_data.script.?; ok {
			_ = ecs_add_script(entity, script_data.script_name)
		}

		append(&current_scene.entities, entity)
	}

	log_info(.ENGINE, "Scene loaded successfully: %s", scene_data.name)
	return true
}

// Save the current scene to disk
scene_save :: proc(path: string = "") -> bool {
	if !current_scene.loaded {
		log_error(.ENGINE, "No scene is currently loaded")
		return false
	}

	save_path := path
	if save_path == "" {
		// If no path provided, use the current scene path
		save_path = current_scene.path

		// If no path set, create one in assets/scenes
		if save_path == "" {
			save_path = fmt.tprintf("assets/scenes/%s.json", current_scene.name)
		}
	}

	log_info(.ENGINE, "Saving scene to: %s", save_path)

	// Create scene data for serialization
	scene_data := Scene_Data {
		name     = current_scene.name,
		version  = "0.1",
		entities = make([dynamic]Entity_Data),
	}
	defer delete(scene_data.entities)

	// Convert entities to serializable format
	for entity in current_scene.entities {
		entity_data := Entity_Data {
			name = fmt.tprintf("Entity_%d", entity),
		}

		// Get transform data
		if transform := ecs_get_transform(entity); transform != nil {
			entity_data.transform = Transform_Data {
				position = {transform.position.x, transform.position.y, transform.position.z},
				rotation = {transform.rotation.x, transform.rotation.y, transform.rotation.z},
				scale    = {transform.scale.x, transform.scale.y, transform.scale.z},
			}
		}

		// Get renderer data
		if renderer := ecs_get_renderer(entity); renderer != nil {
			entity_data.renderer = Renderer_Data {
				mesh_path     = renderer.mesh,
				material_path = renderer.material,
			}
		}

		// Get camera data
		if camera := ecs_get_camera(entity); camera != nil {
			entity_data.camera = Camera_Data {
				fov     = camera.fov,
				near    = camera.near,
				far     = camera.far,
				is_main = camera.is_main,
			}
		}

		// Get light data
		if light := ecs_get_light(entity); light != nil {
			entity_data.light = Light_Data {
				light_type = fmt.tprintf("%v", light.light_type),
				color      = light.color,
				intensity  = light.intensity,
				range      = light.range,
				spot_angle = light.spot_angle,
			}
		}

		// Get script data
		if script := ecs_get_script(entity); script != nil {
			entity_data.script = Script_Data {
				script_name = script.script_name,
			}
		}

		append(&scene_data.entities, entity_data)
	}

	// Convert to JSON
	json_data, err := json.marshal(scene_data)
	if err != nil {
		log_error(.ENGINE, "Failed to marshal scene data: %v", err)
		return false
	}
	defer delete(json_data)

	// Ensure directory exists
	dir := filepath.dir(save_path)
	if !os.exists(dir) {
		os.make_directory(dir)
	}

	// Write to file
	file, open_err := os.open(save_path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o666)
	if open_err != 0 {
		log_error(.ENGINE, "Failed to open scene file: %s (Error: %v)", save_path, open_err)
		return false
	}
	defer os.close(file)

	bytes_written, write_err := os.write(file, json_data)
	if write_err != 0 {
		log_error(.ENGINE, "Failed to write scene file: %s (Error: %v)", save_path, write_err)
		return false
	}

	if bytes_written != len(json_data) {
		log_error(
			.ENGINE,
			"Failed to write all scene data: %s (Wrote %d of %d bytes)",
			save_path,
			bytes_written,
			len(json_data),
		)
		return false
	}

	// Update scene info
	current_scene.path = strings.clone(save_path)
	current_scene.dirty = false

	// Update available scenes
	scene_scan_available_scenes()

	log_info(.ENGINE, "Scene saved successfully: %s", save_path)
	return true
}

// Unload the current scene
scene_unload :: proc() {
	if !current_scene.loaded {
		return
	}

	log_info(.ENGINE, "Unloading scene: %s", current_scene.name)

	// Destroy all entities
	for entity in current_scene.entities {
		ecs_destroy_entity(entity)
	}

	// Clear the entities list
	clear(&current_scene.entities)

	// Free scene name and path
	delete(current_scene.name)
	delete(current_scene.path)

	// Reset scene state
	current_scene.name = "Untitled"
	current_scene.path = ""
	current_scene.loaded = false
	current_scene.dirty = false

	// Reset entity manager
	entity_manager.next_entity_id = 1
}

// Add an entity to the current scene
scene_add_entity :: proc(entity: Entity) {
	if !current_scene.loaded {
		log_warning(.ENGINE, "No scene is currently loaded")
		return
	}

	append(&current_scene.entities, entity)
	current_scene.dirty = true
}

// Remove an entity from the current scene
scene_remove_entity :: proc(entity: Entity) {
	if !current_scene.loaded {
		log_warning(.ENGINE, "No scene is currently loaded")
		return
	}

	// Find and remove the entity
	for i := 0; i < len(current_scene.entities); i += 1 {
		if current_scene.entities[i] == entity {
			unordered_remove(&current_scene.entities, i)
			current_scene.dirty = true
			return
		}
	}

	log_warning(.ENGINE, "Entity %d not found in scene", entity)
}

// Get all entities in the current scene
scene_get_entities :: proc(allocator := context.allocator) -> []Entity {
	if !current_scene.loaded {
		return {}
	}

	return slice.clone(current_scene.entities[:])
}

// Get the main camera entity (or nil if none exists)
scene_get_main_camera :: proc() -> Entity {
	if !current_scene.loaded {
		return 0
	}

	// Find entities with camera components
	camera_entities := ecs_get_entities_with_component(.CAMERA)
	defer delete(camera_entities)

	for entity in camera_entities {
		camera := ecs_get_camera(entity)
		if camera != nil && camera.is_main {
			return entity
		}
	}

	return 0 // No main camera found
}

// Check if a scene is currently loaded
scene_is_loaded :: proc() -> bool {
	return current_scene.loaded
}

// Mark the current scene as dirty (has unsaved changes)
scene_mark_dirty :: proc() {
	if current_scene.loaded {
		current_scene.dirty = true
	}
}

// Check if the current scene has unsaved changes
scene_is_dirty :: proc() -> bool {
	return current_scene.loaded && current_scene.dirty
}

// Create an ambulance entity with the provided mesh and texture
create_ambulance_entity :: proc() -> Entity {
	entity := ecs_create_entity()

	// Add transform component
	transform := new(Transform_Component)
	transform^ = Transform_Component {
		_base = Component{type = .TRANSFORM, entity = entity, enabled = true},
		position = {0, 0, 0},
		rotation = {0, 0, 0},
		scale = {1, 1, 1},
	}
	ecs_add_component(entity, cast(^Component)transform)

	// Load model and texture
	model := load_model("assets/meshes/ambulance.glb")
	if model == nil {
		log_error(.ENGINE, "Failed to load ambulance model")
		return entity
	}

	// Load texture from GLB's expected path
	texture := load_texture("assets/meshes/Textures/colormap.png")
	if texture.id == 0 {
		log_error(.ENGINE, "Failed to load ambulance texture from GLB path")
		return entity
	}

	// Set model texture and material properties
	for i in 0 ..< model.materialCount {
		material := &model.materials[i]

		// Set texture and material properties
		material.maps[0].texture = texture
		material.maps[0].color = raylib.WHITE
		material.maps[0].value = 1.0

		log_info(.ENGINE, "Applied texture to material %d", i)
	}

	// Add renderer component with ambulance mesh and texture
	renderer := new(Renderer)
	renderer^ = Renderer {
		type     = .RENDERER,
		entity   = entity,
		enabled  = true,
		mesh     = "assets/meshes/ambulance.glb",
		material = "assets/meshes/Textures/colormap.png", // Use GLB's expected path
		visible  = true,
	}
	ecs_add_component(entity, cast(^Component)renderer)

	// Add the entity to the current scene
	append(&current_scene.entities, entity)
	current_scene.dirty = true

	return entity
}

// Get the camera for rendering
scene_get_camera :: proc() -> raylib.Camera3D {
	if !current_scene.loaded {
		return raylib.Camera3D{}
	}

	// Get main camera entity
	main_camera := scene_get_main_camera()
	if main_camera == 0 {
		return raylib.Camera3D{}
	}

	// Get camera and transform components
	camera := ecs_get_camera(main_camera)
	transform := ecs_get_transform(main_camera)
	if camera == nil || transform == nil {
		return raylib.Camera3D{}
	}

	// Create and return camera
	return raylib.Camera3D {
		position = transform.position,
		target = {transform.position.x, transform.position.y, transform.position.z - 1},
		up = {0, 1, 0},
		fovy = camera.fov,
		projection = .PERSPECTIVE,
	}
}

// Create a new entity with a transform component
create_entity :: proc(position, rotation, scale: raylib.Vector3) -> Entity {
	entity := ecs_create_entity()
	transform := new(Transform_Component)
	transform^ = Transform_Component {
		_base = Component{type = .TRANSFORM, entity = entity, enabled = true},
		position = position,
		rotation = rotation,
		scale = scale,
	}
	ecs_add_component(entity, cast(^Component)transform)
	return entity
}

// Create a new entity with initial transform data
create_entity_from_data :: proc(transform_data: Transform_Data) -> Entity {
	position := raylib.Vector3 {
		transform_data.position[0],
		transform_data.position[1],
		transform_data.position[2],
	}
	rotation := raylib.Vector3 {
		transform_data.rotation[0],
		transform_data.rotation[1],
		transform_data.rotation[2],
	}
	scale := raylib.Vector3 {
		transform_data.scale[0],
		transform_data.scale[1],
		transform_data.scale[2],
	}
	return create_entity(position, rotation, scale)
}

// Save scene to file
save_scene :: proc(scene: ^Scene, path: string) -> bool {
	data := Scene_Data {
		name     = scene.name,
		entities = make([dynamic]Entity_Data),
	}
	defer delete(data.entities)

	// Convert scene entities to serializable format
	for entity in scene.entities {
		entity_data := Entity_Data {
			name = fmt.tprintf("Entity_%d", entity),
		}

		// Get transform data
		if transform := ecs_get_transform(entity); transform != nil {
			entity_data.transform = Transform_Data {
				position = {transform.position.x, transform.position.y, transform.position.z},
				rotation = {transform.rotation.x, transform.rotation.y, transform.rotation.z},
				scale    = {transform.scale.x, transform.scale.y, transform.scale.z},
			}
		}

		// Get renderer data
		if renderer := ecs_get_renderer(entity); renderer != nil {
			entity_data.renderer = Renderer_Data {
				mesh_path     = renderer.mesh,
				material_path = renderer.material,
			}
		}

		// Get camera data
		if camera := ecs_get_camera(entity); camera != nil {
			entity_data.camera = Camera_Data {
				fov  = camera.fov,
				near = camera.near,
				far  = camera.far,
			}
		}

		// Get light data
		if light := ecs_get_light(entity); light != nil {
			entity_data.light = Light_Data {
				light_type = fmt.tprintf("%v", light.light_type),
				color      = light.color,
				intensity  = light.intensity,
				range      = light.range,
				spot_angle = light.spot_angle,
			}
		}

		// Get script data
		if script := ecs_get_script(entity); script != nil {
			entity_data.script = Script_Data {
				script_name = script.script_name,
			}
		}

		append(&data.entities, entity_data)
	}

	// Convert to JSON
	json_data, err := json.marshal(data)
	if err != nil {
		log.error("Failed to marshal scene data:", err)
		return false
	}
	defer delete(json_data)

	// Ensure directory exists
	dir := filepath.dir(path)
	if !os.exists(dir) {
		os.make_directory(dir)
	}

	// Write to file
	file, open_err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o666)
	if open_err != 0 {
		log_error(.ENGINE, "Failed to open scene file: %s (Error: %v)", path, open_err)
		return false
	}
	defer os.close(file)

	bytes_written, write_err := os.write(file, json_data)
	if write_err != 0 {
		log_error(.ENGINE, "Failed to write scene file: %s (Error: %v)", path, write_err)
		return false
	}

	if bytes_written != len(json_data) {
		log_error(
			.ENGINE,
			"Failed to write all scene data: %s (Wrote %d of %d bytes)",
			path,
			bytes_written,
			len(json_data),
		)
		return false
	}

	return true
}

// Load scene from file
load_scene :: proc(path: string) -> ^Scene {
	// Read file
	data_bytes, ok := os.read_entire_file(path)
	if !ok {
		log.error("Failed to load scene file:", path)
		return nil
	}
	defer delete(data_bytes)

	// Parse JSON
	data: Scene_Data
	err := json.unmarshal(data_bytes, &data)
	if err != nil {
		log.error("Failed to parse scene data:", err)
		return nil
	}
	defer {
		for entity in data.entities {
			delete(entity.name)
			if entity.renderer != nil {
				delete(entity.renderer.?.mesh_path)
				delete(entity.renderer.?.material_path)
			}
			if script, ok := entity.script.?; ok {
				delete(script.script_name)
			}
		}
		delete(data.entities)
		delete(data.name)
	}

	// Create new scene
	scene := new(Scene)
	scene.name = data.name
	scene.entities = make([dynamic]Entity)

	// Create entities from data
	for entity_data in data.entities {
		entity := create_entity_from_data(entity_data.transform)
		if entity == 0 {
			continue
		}

		// Add renderer
		if renderer_data, ok := entity_data.renderer.?; ok {
			renderer := ecs_add_renderer(entity)
			if renderer != nil {
				renderer.mesh = renderer_data.mesh_path
				renderer.material = renderer_data.material_path
			}
		}

		// Add camera
		if camera_data, ok := entity_data.camera.?; ok {
			camera := ecs_add_camera(entity)
			if camera != nil {
				camera.fov = camera_data.fov
				camera.near = camera_data.near
				camera.far = camera_data.far
			}
		}

		// Add light
		if light_data, ok := entity_data.light.?; ok {
			light := ecs_add_light(entity)
			if light != nil {
				light.color = light_data.color
				light.intensity = light_data.intensity
				light.range = light_data.range
				light.spot_angle = light_data.spot_angle
				// Parse light type
				switch light_data.light_type {
				case "DIRECTIONAL":
					light.light_type = .DIRECTIONAL
				case "POINT":
					light.light_type = .POINT
				case "SPOT":
					light.light_type = .SPOT
				}
			}
		}

		// Add script
		if script_data, ok := entity_data.script.?; ok {
			_ = ecs_add_script(entity, script_data.script_name)
		}

		append(&scene.entities, entity)
	}

	return scene
}
