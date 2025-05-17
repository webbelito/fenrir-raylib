package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import raylib "vendor:raylib"

// Scene Manager structure
Scene_Manager :: struct {
	scenes:             [dynamic]Scene, // All loaded scenes
	current_scene:      ^Scene, // Currently active scene
	initialized:        bool, // Whether the scene manager is initialized
	scene_path:         string, // Path to save scenes
	entity_map:         map[Entity]Entity, // Map from old scene entities to new ECS entities
	entity_map_reverse: map[Entity]Entity, // Map from ECS entities to scene entities
}

// Scene structure
Scene :: struct {
	name:     string,
	path:     string,
	entities: [dynamic]Entity,
	loaded:   bool,
	dirty:    bool,
}

// Scene file format for JSON serialization
Scene_Data :: struct {
	name:     string `json:"name"`,
	version:  string `json:"version"`,
	entities: [dynamic]Entity_Data `json:"entities"`,
}

Entity_Data :: struct {
	name:       string `json:"name"`,
	components: [dynamic]Component_Data `json:"components"`,
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

// Global scene manager instance
scene_manager: Scene_Manager

// Initialize the scene manager
scene_manager_init :: proc() {
	log_info(.ENGINE, "Initializing scene manager")

	// Create a new current scene
	scene_manager.scenes = make([dynamic]Scene)

	// Add an initial empty scene
	new_scene := Scene {
		name     = "Untitled",
		path     = "",
		entities = make([dynamic]Entity),
		loaded   = true,
		dirty    = false,
	}

	append(&scene_manager.scenes, new_scene)
	scene_manager.current_scene = &scene_manager.scenes[0]

	// Create root entity
	root_entity := ecs_create_entity()
	ecs_set_entity_name(root_entity, "Root")

	if root_entity == 0 {
		log_error(.ENGINE, "Failed to create root entity")
		return
	}

	// Add a default Transform component to the root entity
	root_transform := Transform {
		position     = raylib.Vector3{0, 0, 0},
		rotation     = raylib.Vector3{0, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(root_entity, Transform, root_transform)

	append(&scene_manager.current_scene.entities, root_entity)

	// Initialize entity maps
	scene_manager.entity_map = make(map[Entity]Entity)
	scene_manager.entity_map_reverse = make(map[Entity]Entity)

	// Create scenes directory if it doesn't exist
	scene_path := "assets/scenes"
	if !os.exists(scene_path) {
		os.make_directory(scene_path)
	}

	scene_manager.scene_path = scene_path
	scene_manager.initialized = true
	log_info(.ENGINE, "Scene manager initialized")
}

// Shutdown the scene manager
scene_manager_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down scene manager")

	// Unload the current scene if loaded
	if scene_manager.current_scene.loaded {
		scene_manager_cleanup()
	}

	// Free resources
	for _, i in scene_manager.scenes {
		delete(scene_manager.scenes[i].entities)
		delete(scene_manager.scenes[i].name)
		delete(scene_manager.scenes[i].path)
	}
	delete(scene_manager.scenes)

	// Free entity mappings
	delete(scene_manager.entity_map)
	delete(scene_manager.entity_map_reverse)

	scene_manager.initialized = false
}

// Scan for available scenes in the assets/scenes directory
scene_manager_scan_available_scenes :: proc() -> []string {
	scenes_dir := scene_manager.scene_path
	scene_files := make([dynamic]string)

	// Check if the directory exists
	if !os.exists(scenes_dir) {
		log_warning(.ENGINE, "Scenes directory '%s' does not exist", scenes_dir)
		return nil
	}

	// Read directory contents
	dir, err := os.open(scenes_dir)
	if err != os.ERROR_NONE {
		log_error(.ENGINE, "Failed to open scenes directory: %v", err)
		return nil
	}
	defer os.close(dir)

	// Read all files in the directory
	files, read_err := os.read_dir(dir, -1)
	if read_err != os.ERROR_NONE {
		log_error(.ENGINE, "Failed to read scenes directory: %v", read_err)
		return nil
	}
	defer os.file_info_slice_delete(files)

	// Filter for .json files
	for file in files {
		if !file.is_dir {
			// Add to available scenes list with .json extension
			scene_name := strings.clone(file.name)
			if !strings.has_suffix(scene_name, ".json") {
				scene_name = fmt.tprintf("%s.json", scene_name)
			}
			append(&scene_files, scene_name)
			log_debug(.ENGINE, "Found scene: %s", scene_name)
		}
	}

	log_info(.ENGINE, "Found %d scene(s)", len(scene_files))
	return scene_files[:]
}

// Clean up the current scene
scene_manager_cleanup :: proc() {
	if !scene_manager.initialized {
		return
	}

	if scene_manager.current_scene.loaded {
		// Destroy all entities
		for entity in scene_manager.current_scene.entities {
			ecs_destroy_entity(entity)
		}

		// Clear entities list
		clear(&scene_manager.current_scene.entities)

		// Free scene name and path
		delete(scene_manager.current_scene.name)
		delete(scene_manager.current_scene.path)

		scene_manager.current_scene.loaded = false
		scene_manager.current_scene.dirty = false
	}
}

// Create a new scene
scene_manager_new :: proc(name: string) -> (scene: ^Scene, ok: bool) {
	log_info(.ENGINE, "Creating new scene: %s", name)

	// Cleanup existing scene if loaded
	if scene_manager.current_scene.loaded {
		scene_manager_cleanup()
	}

	// Reset entity manager to ensure clean entity IDs
	registry.next_entity_id = 1

	// Create new scene and add to scenes list
	new_scene := Scene {
		name     = strings.clone(name),
		path     = "",
		entities = make([dynamic]Entity),
		loaded   = true,
		dirty    = true,
	}

	append(&scene_manager.scenes, new_scene)

	// Set as current scene
	scene_manager.current_scene = &scene_manager.scenes[len(scene_manager.scenes) - 1]
	scene = scene_manager.current_scene

	// Create root entity
	root_entity := ecs_create_entity()
	ecs_set_entity_name(root_entity, "Root")

	if root_entity == 0 {
		log_error(.ENGINE, "Failed to create root entity")
		scene_manager_cleanup()
		return nil, false
	}

	// Add a default Transform component to the root entity
	root_transform := Transform {
		position     = raylib.Vector3{0, 0, 0},
		rotation     = raylib.Vector3{0, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(root_entity, Transform, root_transform)

	append(&scene_manager.current_scene.entities, root_entity)

	// Create default camera
	camera_entity := ecs_create_entity()
	ecs_set_entity_name(camera_entity, "Main Camera")

	if camera_entity == 0 {
		log_error(.ENGINE, "Failed to create camera entity")
		scene_manager_cleanup()
		return nil, false
	}

	// Set transform values for camera
	transform := Transform {
		position     = raylib.Vector3{0, 5, -10},
		rotation     = raylib.Vector3{30, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(camera_entity, Transform, transform)

	// Add camera component
	camera := Camera {
		fov     = 45.0,
		near    = 0.1,
		far     = 1000.0,
		is_main = true,
	}
	ecs_add_component(camera_entity, Camera, camera)

	// Add camera to scene
	append(&scene_manager.current_scene.entities, camera_entity)

	log_info(.ENGINE, "Created new scene: %s", name)
	return scene, true
}

// Create a new entity in the current scene
scene_manager_create_entity :: proc(name: string = "") -> Entity {
	entity := ecs_create_entity()

	// Set the entity name if provided
	if name != "" {
		ecs_set_entity_name(entity, name)
	}

	// Add a default Transform component
	transform := Transform {
		position     = raylib.Vector3{0, 0, 0},
		rotation     = raylib.Vector3{0, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(entity, Transform, transform)

	// Add to current scene
	if scene_manager.initialized && scene_manager.current_scene.loaded {
		if scene_manager.current_scene.entities == nil {
			scene_manager.current_scene.entities = make([dynamic]Entity)
		}
		append(&scene_manager.current_scene.entities, entity)
	}

	return entity
}

// Delete an entity
scene_manager_delete_entity :: proc(entity: Entity) {
	if !scene_manager.current_scene.loaded || entity == 0 {
		return
	}

	// Remove from scene
	for i := 0; i < len(scene_manager.current_scene.entities); i += 1 {
		if scene_manager.current_scene.entities[i] == entity {
			ordered_remove(&scene_manager.current_scene.entities, i)
			break
		}
	}

	// Destroy the entity
	ecs_destroy_entity(entity)

	scene_manager.current_scene.dirty = true
}

// Load a scene from disk
scene_manager_load :: proc(path: string) -> bool {
	if scene_manager.current_scene.loaded && scene_manager.current_scene.dirty {
		log_warning(.ENGINE, "Current scene has unsaved changes, forcing load anyway")
	}

	// Unload current scene if loaded
	if scene_manager.current_scene.loaded {
		scene_manager_cleanup()
	}

	// Reset entity manager to ensure clean entity IDs
	registry.next_entity_id = 1

	// Handle relative paths by prepending assets/scenes if needed
	full_path := path
	if !strings.has_prefix(path, "/") && !strings.has_prefix(path, "assets/scenes/") {
		full_path = fmt.tprintf("assets/scenes/%s", path)
	}

	// Ensure the path has .json extension
	if !strings.has_suffix(full_path, ".json") {
		full_path = fmt.tprintf("%s.json", full_path)
	}

	// Check if file exists
	if !os.exists(full_path) {
		log_error(.ENGINE, "Scene file does not exist: %s", full_path)
		return false
	}

	// Read file contents
	data, ok := os.read_entire_file(full_path)
	if !ok {
		log_error(.ENGINE, "Failed to read scene file: %s", full_path)
		return false
	}
	defer delete(data)

	// Parse JSON
	scene_data: Scene_Data
	if err := json.unmarshal(data, &scene_data); err != nil {
		log_error(.ENGINE, "Failed to parse scene file: %v", err)
		return false
	}

	// Get scene name from filename
	filename := filepath.base(full_path)
	scene_name := strings.trim_suffix(filename, filepath.ext(filename))

	// Initialize new scene
	scene_manager.current_scene.name = strings.clone(scene_name)
	scene_manager.current_scene.path = strings.clone(full_path)
	scene_manager.current_scene.loaded = true
	scene_manager.current_scene.dirty = false
	scene_manager.current_scene.entities = make([dynamic]Entity)

	// Create root entity
	root_entity := ecs_create_entity()
	ecs_set_entity_name(root_entity, "Root")

	if root_entity == 0 {
		log_error(.ENGINE, "Failed to create root entity")
		scene_manager_cleanup()
		return false
	}

	// Add a default Transform component to the root entity
	root_transform := Transform {
		position     = raylib.Vector3{0, 0, 0},
		rotation     = raylib.Vector3{0, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(root_entity, Transform, root_transform)

	append(&scene_manager.current_scene.entities, root_entity)

	// Load scene entities
	for entity_data in scene_data.entities {
		entity := ecs_create_entity()
		ecs_set_entity_name(entity, entity_data.name)

		if entity == 0 {
			log_error(.ENGINE, "Failed to create entity")
			continue
		}

		// Add to scene
		append(&scene_manager.current_scene.entities, entity)

		// TODO: Deserialize all components
		// This will need to be reimplemented with the new ECS
	}

	// If no main camera exists, create one
	if scene_manager_get_main_camera() == 0 {
		camera_entity := ecs_create_entity()
		ecs_set_entity_name(camera_entity, "Main Camera")

		if camera_entity == 0 {
			log_error(.ENGINE, "Failed to create default camera entity")
			scene_manager_cleanup()
			return false
		}

		// Add transform component
		transform := Transform {
			position     = raylib.Vector3{0, 5, -10},
			rotation     = raylib.Vector3{30, 0, 0},
			scale        = raylib.Vector3{1, 1, 1},
			local_matrix = raylib.Matrix(1),
			world_matrix = raylib.Matrix(1),
			dirty        = true,
		}
		ecs_add_component(camera_entity, Transform, transform)

		// Add camera component
		camera := Camera {
			fov     = 45.0,
			near    = 0.1,
			far     = 1000.0,
			is_main = true,
		}
		ecs_add_component(camera_entity, Camera, camera)

		// Add camera to scene
		append(&scene_manager.current_scene.entities, camera_entity)
	}

	log_info(.ENGINE, "Loaded scene: %s", full_path)
	return true
}

// Save the current scene to disk
scene_manager_save :: proc(path: string = "") -> bool {
	if !scene_manager.current_scene.loaded {
		log_error(.ENGINE, "No scene is currently loaded")
		return false
	}

	save_path := path
	if save_path == "" {
		// If no path provided, use the current scene path
		save_path = scene_manager.current_scene.path

		// If no path set, create one in assets/scenes
		if save_path == "" {
			// Use the scene name directly
			save_path = fmt.tprintf("assets/scenes/%s", scene_manager.current_scene.name)
		}
	} else {
		// If a path is provided, ensure it's in the scenes directory
		if !strings.has_prefix(save_path, "assets/scenes/") {
			save_path = fmt.tprintf("assets/scenes/%s", save_path)
		}
	}

	// Always ensure the path has .json extension
	if !strings.has_suffix(save_path, ".json") {
		save_path = fmt.tprintf("%s.json", save_path)
	}

	log_info(.ENGINE, "Saving scene to: %s", save_path)

	// Create scene data for serialization
	scene_data := Scene_Data {
		name     = scene_manager.current_scene.name,
		version  = "0.1",
		entities = make([dynamic]Entity_Data),
	}
	defer delete(scene_data.entities)

	// Convert entities to serializable format
	for entity in scene_manager.current_scene.entities {
		if entity == 0 {
			continue // Skip root entity
		}

		entity_data := Entity_Data {
			name       = ecs_get_entity_name(entity),
			components = make([dynamic]Component_Data),
		}

		// Just manually add each component
		if transform := ecs_get_component(entity, Transform); transform != nil {
			comp := Component_Data(transform^)
			append(&entity_data.components, comp)
		}

		if renderer := ecs_get_component(entity, Renderer); renderer != nil {
			comp := Component_Data(renderer^)
			append(&entity_data.components, comp)
		}

		if camera := ecs_get_component(entity, Camera); camera != nil {
			comp := Component_Data(camera^)
			append(&entity_data.components, comp)
		}

		if light := ecs_get_component(entity, Light); light != nil {
			comp := Component_Data(light^)
			append(&entity_data.components, comp)
		}

		if script := ecs_get_component(entity, Script); script != nil {
			comp := Component_Data(script^)
			append(&entity_data.components, comp)
		}

		// Only add entities that have components
		if len(entity_data.components) > 0 {
			append(&scene_data.entities, entity_data)
		}
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
		if err := os.make_directory(dir); err != 0 {
			log_error(.ENGINE, "Failed to create directory: %s (Error: %v)", dir, err)
			return false
		}
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
	scene_manager.current_scene.path = strings.clone(save_path)
	scene_manager.current_scene.dirty = false

	// Update available scenes
	scene_manager_scan_available_scenes()

	log_info(.ENGINE, "Scene saved successfully: %s", save_path)
	return true
}

// Unload the current scene
scene_manager_unload :: proc() {
	if !scene_manager.current_scene.loaded {
		return
	}

	log_info(.ENGINE, "Unloading scene: %s", scene_manager.current_scene.name)

	// Clear command stacks
	command_manager_clear()

	// Clear the entities list
	clear(&scene_manager.current_scene.entities)

	// Free scene name and path
	delete(scene_manager.current_scene.name)
	delete(scene_manager.current_scene.path)

	// Reset scene state
	scene_manager.current_scene.name = "Untitled"
	scene_manager.current_scene.path = ""
	scene_manager.current_scene.loaded = false
	scene_manager.current_scene.dirty = false

	// Reset entity manager
	registry.next_entity_id = 1

	log_info(.ENGINE, "Scene unloaded")
}

// Add an entity to the current scene
scene_manager_add_entity :: proc(entity: Entity) {
	if !scene_manager.current_scene.loaded {
		log_warning(.ENGINE, "No scene is currently loaded")
		return
	}

	append(&scene_manager.current_scene.entities, entity)
	scene_manager.current_scene.dirty = true
}

// Remove an entity from the current scene
scene_manager_remove_entity :: proc(entity: Entity) {
	if !scene_manager.current_scene.loaded {
		log_warning(.ENGINE, "No scene is currently loaded")
		return
	}

	// Find and remove the entity
	for i := 0; i < len(scene_manager.current_scene.entities); i += 1 {
		if scene_manager.current_scene.entities[i] == entity {
			unordered_remove(&scene_manager.current_scene.entities, i)
			scene_manager.current_scene.dirty = true
			return
		}
	}

	log_warning(.ENGINE, "Entity %d not found in scene", entity)
}

// Get all entities in the current scene
scene_manager_get_entities :: proc(allocator := context.allocator) -> []Entity {
	if !scene_manager.current_scene.loaded {
		return {}
	}

	return slice.clone(scene_manager.current_scene.entities[:])
}

// Get the main camera entity (or nil if none exists)
scene_manager_get_main_camera :: proc() -> Entity {
	if !scene_manager.current_scene.loaded {
		return 0
	}

	// Find entities with camera components
	camera_entities := ecs_query(Camera)
	defer delete(camera_entities)

	for entity in camera_entities {
		camera := ecs_get_component(entity, Camera)
		if camera != nil && camera.is_main {
			return entity
		}
	}

	return 0 // No main camera found
}

// Check if a scene is currently loaded
scene_manager_is_loaded :: proc() -> bool {
	return scene_manager.current_scene.loaded
}

// Mark the current scene as dirty (has unsaved changes)
scene_manager_mark_dirty :: proc() {
	if scene_manager.current_scene.loaded {
		scene_manager.current_scene.dirty = true
	}
}

// Check if the current scene has unsaved changes
scene_manager_is_dirty :: proc() -> bool {
	return scene_manager.current_scene.loaded && scene_manager.current_scene.dirty
}

// Create an ambulance entity with the provided mesh and texture
scene_manager_create_ambulance_entity :: proc() -> Entity {
	entity := ecs_create_entity()
	ecs_set_entity_name(entity, "Ambulance")

	// Add transform component
	transform := Transform {
		position     = raylib.Vector3{0, 0, 0},
		rotation     = raylib.Vector3{0, 0, 0},
		scale        = raylib.Vector3{1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	ecs_add_component(entity, Transform, transform)

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
	renderer := Renderer {
		visible       = true,
		model_type    = .AMBULANCE,
		mesh_path     = "assets/meshes/ambulance.glb",
		material_path = "assets/meshes/Textures/colormap.png",
	}
	ecs_add_component(entity, Renderer, renderer)

	// Add the entity to the current scene
	append(&scene_manager.current_scene.entities, entity)
	scene_manager.current_scene.dirty = true

	return entity
}

// Get the camera for rendering
scene_manager_get_camera :: proc() -> raylib.Camera3D {
	if !scene_manager.current_scene.loaded {
		return raylib.Camera3D{}
	}

	// Get main camera entity
	main_camera := scene_manager_get_main_camera()
	if main_camera == 0 {
		return raylib.Camera3D{}
	}

	// Get camera and transform components
	camera := ecs_get_component(main_camera, Camera)
	transform := ecs_get_component(main_camera, Transform)
	if camera == nil || transform == nil {
		return raylib.Camera3D{}
	}

	// Calculate forward direction based on rotation
	forward := raylib.Vector3 {
		math.sin(transform.rotation.y) * math.cos(transform.rotation.x),
		-math.sin(transform.rotation.x),
		math.cos(transform.rotation.y) * math.cos(transform.rotation.x),
	}

	// Create and return camera
	return raylib.Camera3D {
		position   = transform.position,
		target     = transform.position + forward * 10.0, // Look 10 units ahead
		up         = {0, 1, 0},
		fovy       = camera.fov,
		projection = .PERSPECTIVE,
	}
}

// Update the scene
scene_manager_update :: proc() {
	if !scene_manager.current_scene.loaded {
		return
	}

	// TODO: Update all entities in the scene
	// This will need to be reimplemented with the new ECS
}

// Render the scene
scene_manager_render :: proc() {
	if !scene_manager.current_scene.loaded {
		return
	}

	// Draw grid
	grid_size := 20
	grid_spacing := 1.0
	grid_color := raylib.DARKGRAY

	// Draw grid lines
	for i := -grid_size; i <= grid_size; i += 1 {
		// X-axis lines
		raylib.DrawLine3D(
			{cast(f32)i * cast(f32)grid_spacing, 0, -cast(f32)grid_size * cast(f32)grid_spacing},
			{cast(f32)i * cast(f32)grid_spacing, 0, cast(f32)grid_size * cast(f32)grid_spacing},
			grid_color,
		)
		// Z-axis lines
		raylib.DrawLine3D(
			{-cast(f32)grid_size * cast(f32)grid_spacing, 0, cast(f32)i * cast(f32)grid_spacing},
			{cast(f32)grid_size * cast(f32)grid_spacing, 0, cast(f32)i * cast(f32)grid_spacing},
			grid_color,
		)
	}

	// Draw coordinate axes
	axis_length := cast(f32)grid_size * cast(f32)grid_spacing
	raylib.DrawLine3D({0, 0, 0}, {axis_length, 0, 0}, raylib.RED) // X axis
	raylib.DrawLine3D({0, 0, 0}, {0, axis_length, 0}, raylib.GREEN) // Y axis
	raylib.DrawLine3D({0, 0, 0}, {0, 0, axis_length}, raylib.BLUE) // Z axis

	// Render all entities
	for entity in scene_manager.current_scene.entities {
		// Skip root entity (Entity 0)
		if entity == 0 {
			continue
		}

		// Skip entities without transform components
		transform := ecs_get_component(entity, Transform)
		if transform == nil {
			continue
		}

		// Skip camera entities
		if ecs_has_component(entity, Camera) {
			continue
		}

		// Get world transform
		world_pos, world_rot, world_scale := get_world_transform(entity)

		// Get renderer component
		renderer := ecs_get_component(entity, Renderer)

		// In editor mode, we want to visualize all entities
		if renderer == nil {
			// Draw a simple gizmo for entities without renderer
			gizmo_size: f32 = 0.5

			// Draw a small cube at the entity's position
			raylib.DrawCube(world_pos, gizmo_size, gizmo_size, gizmo_size, raylib.GRAY)

			// Draw coordinate axes for the gizmo
			axis_length: f32 = gizmo_size * 2
			raylib.DrawLine3D(world_pos, world_pos + {axis_length, 0, 0}, raylib.RED)
			raylib.DrawLine3D(world_pos, world_pos + {0, axis_length, 0}, raylib.GREEN)
			raylib.DrawLine3D(world_pos, world_pos + {0, 0, axis_length}, raylib.BLUE)

			// Draw a wireframe cube to show the entity's bounds
			raylib.DrawCubeWires(
				world_pos,
				gizmo_size * 2,
				gizmo_size * 2,
				gizmo_size * 2,
				raylib.DARKGRAY,
			)

			continue
		}

		if !renderer.visible {
			continue
		}

		// Handle model type changes
		model: ^raylib.Model
		#partial switch renderer.model_type {
		case .CUBE:
			// Create a unique key for this entity's cube
			cube_key := fmt.tprintf("cube_%d", entity)

			// Check if we need to create a new cube
			if model = asset_system.model_cache[cube_key]; model == nil {
				// Create a new cube
				cube := raylib.GenMeshCube(1.0, 1.0, 1.0)
				model_ptr := new(raylib.Model)
				model_ptr^ = raylib.LoadModelFromMesh(cube)
				model_ptr.materials[0].maps[0].color = raylib.RED
				asset_system.model_cache[cube_key] = model_ptr
				model = model_ptr
			}

		case .SPHERE:
			// Create a unique key for this entity's sphere
			sphere_key := fmt.tprintf("sphere_%d", entity)

			// Check if we need to create a new sphere
			if model = asset_system.model_cache[sphere_key]; model == nil {
				// Create a new sphere
				sphere := raylib.GenMeshSphere(0.5, 32, 32)
				model_ptr := new(raylib.Model)
				model_ptr^ = raylib.LoadModelFromMesh(sphere)
				model_ptr.materials[0].maps[0].color = raylib.BLUE
				asset_system.model_cache[sphere_key] = model_ptr
				model = model_ptr
			}

		case .PLANE:
			// Create a unique key for this entity's plane
			plane_key := fmt.tprintf("plane_%d", entity)

			// Check if we need to create a new plane
			if model = asset_system.model_cache[plane_key]; model == nil {
				// Create a new plane
				plane := raylib.GenMeshPlane(1.0, 1.0, 1, 1)
				model_ptr := new(raylib.Model)
				model_ptr^ = raylib.LoadModelFromMesh(plane)
				model_ptr.materials[0].maps[0].color = raylib.GREEN
				asset_system.model_cache[plane_key] = model_ptr
				model = model_ptr
			}

		case .AMBULANCE:
			// Load ambulance model if not in cache
			if model = asset_system.model_cache[renderer.mesh_path]; model == nil {
				model = load_model(renderer.mesh_path)
				if model != nil {
					// Load and apply texture
					texture := load_texture(renderer.material_path)
					if texture.id != 0 {
						for i in 0 ..< model.materialCount {
							material := &model.materials[i]
							material.maps[0].texture = texture
							material.maps[0].color = raylib.WHITE
							material.maps[0].value = 1.0
						}
					}
				}
			}

		case .CUSTOM:
			// Load custom model if not in cache
			if model = asset_system.model_cache[renderer.mesh_path]; model == nil {
				model = load_model(renderer.mesh_path)
				if model != nil {
					// Load and apply material
					if renderer.material_path != "" {
						texture := load_texture(renderer.material_path)
						if texture.id != 0 {
							for i in 0 ..< model.materialCount {
								material := &model.materials[i]
								material.maps[0].texture = texture
								material.maps[0].color = raylib.WHITE
								material.maps[0].value = 1.0
							}
						}
					}
				}
			}
		}

		if model == nil {
			log_error(.ENGINE, "Entity %d: Failed to load model", entity)
			continue
		}

		// Set model transform using world transform
		rotation_matrix := raylib.MatrixRotateXYZ(world_rot)
		translation_matrix := raylib.MatrixTranslate(world_pos.x, world_pos.y, world_pos.z)
		scale_matrix := raylib.MatrixScale(world_scale.x, world_scale.y, world_scale.z)
		model.transform = rotation_matrix * translation_matrix * scale_matrix

		// Draw model
		raylib.DrawModel(model^, {0, 0, 0}, 1.0, raylib.WHITE)
	}
}

// Duplicate an entity
scene_manager_duplicate_entity :: proc(entity: Entity) -> Entity {
	if !scene_manager.current_scene.loaded {
		return 0
	}

	// Get the entity name
	name := ecs_get_entity_name(entity)
	if name == "" {
		name = fmt.tprintf("Entity_%d", entity)
	}

	// Create a new entity
	new_entity := ecs_create_entity()
	ecs_set_entity_name(new_entity, fmt.tprintf("%s (Copy)", name))

	if new_entity == 0 {
		return 0
	}

	// Copy all components from the original entity
	if transform := ecs_get_component(entity, Transform); transform != nil {
		new_transform := Transform {
			position     = transform.position,
			rotation     = transform.rotation,
			scale        = transform.scale,
			local_matrix = transform.local_matrix,
			world_matrix = transform.world_matrix,
			dirty        = true,
		}
		ecs_add_component(new_entity, Transform, new_transform)
	}

	if renderer := ecs_get_component(entity, Renderer); renderer != nil {
		new_renderer := Renderer {
			visible       = renderer.visible,
			model_type    = renderer.model_type,
			mesh_path     = renderer.mesh_path,
			material_path = renderer.material_path,
		}
		ecs_add_component(new_entity, Renderer, new_renderer)
	}

	if camera := ecs_get_component(entity, Camera); camera != nil {
		new_camera := Camera {
			fov     = camera.fov,
			near    = camera.near,
			far     = camera.far,
			is_main = false, // Ensure only one main camera
		}
		ecs_add_component(new_entity, Camera, new_camera)
	}

	if light := ecs_get_component(entity, Light); light != nil {
		new_light := Light {
			light_type = light.light_type,
			color      = light.color,
			intensity  = light.intensity,
			range      = light.range,
			spot_angle = light.spot_angle,
		}
		ecs_add_component(new_entity, Light, new_light)
	}

	if script := ecs_get_component(entity, Script); script != nil {
		new_script := Script {
			script_name = script.script_name,
		}
		ecs_add_component(new_entity, Script, new_script)
	}

	// Add the new entity to the scene
	append(&scene_manager.current_scene.entities, new_entity)
	scene_manager.current_scene.dirty = true

	return new_entity
}

// Set an entity's active state
scene_manager_set_entity_active :: proc(entity: Entity, active: bool) {
	if !scene_manager.current_scene.loaded {
		return
	}

	// TODO: Implement setting entity active state
	// This will need to use the new registry.active_states map

	scene_manager.current_scene.dirty = true
}

// Get world transform for an entity
get_world_transform :: proc(entity: Entity) -> (raylib.Vector3, raylib.Vector3, raylib.Vector3) {
	transform := ecs_get_component(entity, Transform)
	if transform == nil {
		return raylib.Vector3{0, 0, 0}, raylib.Vector3{0, 0, 0}, raylib.Vector3{1, 1, 1}
	}

	// For now, just return local transform
	// TODO: Implement proper world transform calculation using parent transforms
	return transform.position, transform.rotation, transform.scale
}

// Serialize a component to Component_Data
serialize_component :: proc(
	component: rawptr,
	type: Component_Type,
) -> (
	data: Component_Data,
	ok: bool,
) {
	if component == nil {
		return
	}

	#partial switch type {
	case .TRANSFORM:
		transform := cast(^Transform)component
		data = transform^
		ok = true

	case .RENDERER:
		renderer := cast(^Renderer)component
		data = renderer^
		ok = true

	case .CAMERA:
		camera := cast(^Camera)component
		data = camera^
		ok = true

	case .LIGHT:
		light := cast(^Light)component
		data = light^
		ok = true

	case .SCRIPT:
		script := cast(^Script)component
		data = script^
		ok = true
	}

	return
}
