package main

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import raylib "vendor:raylib"

// Node structure
Node :: struct {
	id:        Entity,
	name:      string,
	parent_id: Entity,
	children:  [dynamic]Entity,
	expanded:  bool, // Whether the node is expanded in the scene tree
}

// Scene structure
Scene :: struct {
	name:     string,
	path:     string,
	nodes:    map[Entity]Node, // Map of entity ID to Node
	root_id:  Entity, // The root node's entity ID (always 0)
	entities: [dynamic]Entity,
	loaded:   bool,
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
	current_scene.nodes = make(map[Entity]Node)
	current_scene.root_id = 0

	// Create root node
	root_node := Node {
		id        = 0,
		name      = "Root",
		parent_id = 0, // Root is its own parent
		children  = make([dynamic]Entity),
		expanded  = true, // Root node starts expanded
	}
	current_scene.nodes[0] = root_node

	// Initialize the available scenes list
	available_scenes = make([dynamic]string)

	// Scan for available scenes
	scene_scan_available_scenes()

	log_info(.ENGINE, "Scene system initialized")
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

	// Walk through the directory
	filepath.walk(
		scenes_dir,
		proc(info: os.File_Info, in_err: os.Errno, user_data: rawptr) -> (os.Errno, bool) {
			if in_err != os.ERROR_NONE {
				log_error(.ENGINE, "Error accessing path: %v", in_err)
				return in_err, false
			}

			if !info.is_dir && strings.has_suffix(info.name, ".json") {
				// Add to available scenes list
				scene_name := strings.clone(info.name)
				append(&available_scenes, scene_name)
				log_debug(.ENGINE, "Found scene: %s", scene_name)
			}

			return os.ERROR_NONE, true
		},
		nil,
	)

	log_info(.ENGINE, "Found %d scene(s)", len(available_scenes))
}

// Create a new scene
scene_new :: proc(name: string) -> bool {
	log_info(.ENGINE, "Creating new scene: %s", name)

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
	current_scene.nodes = make(map[Entity]Node)
	current_scene.entities = make([dynamic]Entity)

	// Create root node (always entity ID 0)
	current_scene.root_id = 0
	root_node := Node {
		id        = 0,
		name      = "Root",
		parent_id = 0, // Root is its own parent
		children  = make([dynamic]Entity),
		expanded  = true, // Root node starts expanded
	}
	current_scene.nodes[0] = root_node

	// Add root to entities list
	append(&current_scene.entities, 0)

	log_info(.ENGINE, "Created root node with ID: %d", current_scene.root_id)
	return true
}

// Create a new node in the scene
create_node :: proc(name: string, parent_id: Entity = 0) -> Entity {
	log_info(.ENGINE, "Creating new node: %s with parent: %d", name, parent_id)

	if !current_scene.loaded {
		log_error(.ENGINE, "No scene is currently loaded")
		return 0
	}

	// Verify parent exists
	if parent_id != 0 {
		if _, ok := current_scene.nodes[parent_id]; !ok {
			log_error(.ENGINE, "Parent node not found: %d", parent_id)
			return 0
		}
	}

	// Create the entity for this node
	entity := ecs_create_entity()
	if entity == 0 {
		log_error(.ENGINE, "Failed to create entity")
		return 0
	}
	log_info(.ENGINE, "Created entity for node: %d", entity)

	// Create the node
	node := Node {
		id        = entity,
		name      = strings.clone(name),
		parent_id = parent_id,
		children  = make([dynamic]Entity),
		expanded  = true, // New nodes start expanded
	}

	// Add to scene
	current_scene.nodes[entity] = node
	log_info(.ENGINE, "Added node to scene map")

	// Add to parent's children
	if parent, ok := current_scene.nodes[parent_id]; ok {
		append(&parent.children, entity)
		current_scene.nodes[parent_id] = parent
		log_info(.ENGINE, "Added node to parent's children")
	} else {
		log_error(.ENGINE, "Parent node not found: %d", parent_id)
		delete_key(&current_scene.nodes, entity)
		delete(node.name)
		delete(node.children)
		return 0
	}

	// Add transform component to the entity
	if transform := ecs_add_transform(entity, {0, 0, 0}, {0, 0, 0}, {1, 1, 1}); transform == nil {
		log_error(.ENGINE, "Failed to add transform component")
		delete_key(&current_scene.nodes, entity)
		delete(node.name)
		delete(node.children)
		return 0
	}
	log_info(.ENGINE, "Added transform component")

	// Add to scene entities
	append(&current_scene.entities, entity)
	current_scene.dirty = true
	log_info(.ENGINE, "Added entity to scene entities list")

	return entity
}

// Delete a node and all its children
delete_node :: proc(node_id: Entity) {
	if !current_scene.loaded || node_id == 0 {
		return
	}

	node := current_scene.nodes[node_id]

	// First delete all children
	for child_id in node.children {
		delete_node(child_id)
	}

	// Remove from parent's children
	if parent, ok := current_scene.nodes[node.parent_id]; ok {
		for i := 0; i < len(parent.children); i += 1 {
			if parent.children[i] == node_id {
				ordered_remove(&parent.children, i)
				break
			}
		}
		current_scene.nodes[node.parent_id] = parent
	}

	// Remove from scene
	delete_key(&current_scene.nodes, node_id)

	// Remove from entities list
	for i := 0; i < len(current_scene.entities); i += 1 {
		if current_scene.entities[i] == node_id {
			ordered_remove(&current_scene.entities, i)
			break
		}
	}

	// Clean up node resources
	delete(node.name)
	delete(node.children)

	// Destroy the entity
	ecs_destroy_entity(node_id)

	current_scene.dirty = true
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

	// Check if file exists
	if !os.exists(path) {
		log_error(.ENGINE, "Scene file does not exist: %s", path)
		return false
	}

	// Read file contents
	data, ok := os.read_entire_file(path)
	if !ok {
		log_error(.ENGINE, "Failed to read scene file: %s", path)
		return false
	}
	defer delete(data)

	// Parse JSON
	scene_data: Scene_Data
	if err := json.unmarshal(data, &scene_data); err != nil {
		log_error(.ENGINE, "Failed to parse scene file: %v", err)
		return false
	}

	// Initialize new scene
	current_scene.name = strings.clone(scene_data.name)
	current_scene.path = strings.clone(path)
	current_scene.loaded = true
	current_scene.dirty = false
	current_scene.nodes = make(map[Entity]Node)
	current_scene.entities = make([dynamic]Entity)

	// Create root node
	root_node := Node {
		id        = 0,
		name      = "Root",
		parent_id = 0,
		children  = make([dynamic]Entity),
		expanded  = true,
	}
	current_scene.nodes[0] = root_node
	current_scene.root_id = 0

	// First pass: Create all entities and their basic components
	entity_map := make(map[string]Entity) // Map to store entity names to IDs
	defer delete(entity_map)

	for entity_data in scene_data.entities {
		entity := ecs_create_entity()
		if entity == 0 {
			log_error(.ENGINE, "Failed to create entity")
			continue
		}

		// Store entity name mapping
		entity_map[entity_data.name] = entity

		// Add transform component
		ecs_add_transform(
			entity,
			entity_data.transform.position,
			entity_data.transform.rotation,
			entity_data.transform.scale,
		)

		// Add renderer component if present
		if renderer, ok := entity_data.renderer.(Renderer_Data); ok {
			ecs_add_renderer(entity, renderer.mesh_path, renderer.material_path)
		}

		// Add camera component if present
		if camera, ok := entity_data.camera.(Camera_Data); ok {
			ecs_add_camera(entity, camera.fov, camera.near, camera.far, camera.is_main)
		}

		// Add light component if present
		if light, ok := entity_data.light.(Light_Data); ok {
			// Convert light type string to enum
			light_type: Light_Type
			switch light.light_type {
			case "DIRECTIONAL":
				light_type = .DIRECTIONAL
			case "POINT":
				light_type = .POINT
			case "SPOT":
				light_type = .SPOT
			case:
				light_type = .POINT
			}

			ecs_add_light(
				entity,
				light_type,
				light.color,
				light.intensity,
				light.range,
				light.spot_angle,
			)
		}

		// Add script component if present
		if script, ok := entity_data.script.(Script_Data); ok {
			ecs_add_script(entity, script.script_name)
		}

		// Create node for this entity
		node := Node {
			id        = entity,
			name      = strings.clone(entity_data.name),
			parent_id = 0, // Will be set in second pass
			children  = make([dynamic]Entity),
			expanded  = true,
		}
		current_scene.nodes[entity] = node
		append(&current_scene.entities, entity)
	}

	// Second pass: Set up parent-child relationships
	for entity_data in scene_data.entities {
		if entity, ok := entity_map[entity_data.name]; ok {
			// Get the node
			if node, ok := current_scene.nodes[entity]; ok {
				// If this is a child node, add it to its parent's children
				if node.parent_id != 0 {
					if parent, ok := current_scene.nodes[node.parent_id]; ok {
						append(&parent.children, entity)
						current_scene.nodes[node.parent_id] = parent
					}
				} else {
					// If no parent specified, add to root
					if root, ok := current_scene.nodes[0]; ok {
						append(&root.children, entity)
						current_scene.nodes[0] = root
					}
				}
			}
		}
	}

	log_info(.ENGINE, "Loaded scene: %s", path)
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
		if entity == 0 {
			continue // Skip root node
		}

		if node, ok := current_scene.nodes[entity]; ok {
			entity_data := Entity_Data {
				name = node.name,
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

	// Clean up nodes
	for _, node in current_scene.nodes {
		if node.name != "Root" { 	// Don't delete the root node's name as it's a static string
			delete(node.name)
		}
		delete(node.children)
	}
	clear(&current_scene.nodes)

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
	current_scene.root_id = 0

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
				// Convert light type string to enum
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
