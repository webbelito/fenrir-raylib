package main

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"
import raylib "vendor:raylib"

// Entity hierarchy data
Entity_Hierarchy :: struct {
	parent:   Entity,
	children: [dynamic]Entity,
}

// Entity manager state
Entity_Manager :: struct {
	next_entity_id: Entity,
	transforms:     map[Entity]Transform_Component,
	renderers:      map[Entity]Renderer,
	cameras:        map[Entity]Camera,
	lights:         map[Entity]Light,
	scripts:        map[Entity]Script,
	names:          map[Entity]string,
	active_states:  map[Entity]bool,
	tags:           map[Entity][dynamic]string,
	hierarchies:    map[Entity]Entity_Hierarchy, // New: Store parent-child relationships
}

// Entity is just an ID
Entity :: distinct u64

// Global entity manager instance
entity_manager: Entity_Manager

// Initialize the entity manager
entity_manager_init :: proc() {
	log_info(.ENGINE, "Initializing entity manager")
	entity_manager = Entity_Manager {
		next_entity_id = 1,
		transforms     = make(map[Entity]Transform_Component),
		renderers      = make(map[Entity]Renderer),
		cameras        = make(map[Entity]Camera),
		lights         = make(map[Entity]Light),
		scripts        = make(map[Entity]Script),
		names          = make(map[Entity]string),
		active_states  = make(map[Entity]bool),
		tags           = make(map[Entity][dynamic]string),
		hierarchies    = make(map[Entity]Entity_Hierarchy),
	}
	log_info(.ENGINE, "Entity manager initialized")
}

// Shutdown the entity manager
entity_manager_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down entity manager")
	delete(entity_manager.transforms)
	delete(entity_manager.renderers)
	delete(entity_manager.cameras)
	delete(entity_manager.lights)
	delete(entity_manager.scripts)
	delete(entity_manager.names)
	delete(entity_manager.active_states)
	for _, &tags in entity_manager.tags {
		clear(&tags)
	}
	delete(entity_manager.tags)
	for _, &hierarchy in entity_manager.hierarchies {
		clear(&hierarchy.children)
	}
	delete(entity_manager.hierarchies)
	log_info(.ENGINE, "Entity manager shut down")
}

// Create a new entity
ecs_create_entity :: proc(name: string = "", parent: Entity = 0) -> Entity {
	entity := entity_manager.next_entity_id
	entity_manager.next_entity_id += 1

	// Add transform component by default
	transform := Transform_Component {
		type     = .TRANSFORM,
		entity   = entity,
		enabled  = true,
		position = {0, 0, 0},
		rotation = {0, 0, 0},
		scale    = {1, 1, 1},
	}
	entity_manager.transforms[entity] = transform

	// Set entity name if provided
	if name != "" {
		entity_manager.names[entity] = name
	} else {
		entity_manager.names[entity] = fmt.tprintf("Entity_%d", entity)
	}

	// Set default active state
	entity_manager.active_states[entity] = true

	// Initialize empty tags array
	entity_manager.tags[entity] = make([dynamic]string)

	// Initialize hierarchy
	entity_manager.hierarchies[entity] = Entity_Hierarchy {
		parent   = parent,
		children = make([dynamic]Entity),
	}

	// Add to parent's children if parent exists
	if parent != 0 {
		if hierarchy, ok := entity_manager.hierarchies[parent]; ok {
			append(&hierarchy.children, entity)
			entity_manager.hierarchies[parent] = hierarchy
		}
	}

	return entity
}

// Destroy an entity and all its components
ecs_destroy_entity :: proc(entity: Entity) {
	// First, destroy all children recursively
	if hierarchy, ok := entity_manager.hierarchies[entity]; ok {
		for child in hierarchy.children {
			ecs_destroy_entity(child)
		}
		clear(&hierarchy.children)
	}

	// Remove from parent's children
	if hierarchy, ok := entity_manager.hierarchies[entity]; ok {
		if parent := hierarchy.parent; parent != 0 {
			if parent_hierarchy, parent_ok := entity_manager.hierarchies[parent]; parent_ok {
				for i in 0 ..< len(parent_hierarchy.children) {
					if parent_hierarchy.children[i] == entity {
						ordered_remove(&parent_hierarchy.children, i)
						break
					}
				}
				entity_manager.hierarchies[parent] = parent_hierarchy
			}
		}
	}

	// Remove all components
	delete_key(&entity_manager.transforms, entity)
	delete_key(&entity_manager.renderers, entity)
	delete_key(&entity_manager.cameras, entity)
	delete_key(&entity_manager.lights, entity)
	delete_key(&entity_manager.scripts, entity)
	delete_key(&entity_manager.names, entity)
	delete_key(&entity_manager.active_states, entity)
	delete_key(&entity_manager.tags, entity)
	delete_key(&entity_manager.hierarchies, entity)
}

// Set entity parent
ecs_set_parent :: proc(entity: Entity, parent: Entity) {
	if entity == 0 || entity == parent {
		return
	}

	// Get current hierarchy
	if hierarchy, ok := entity_manager.hierarchies[entity]; ok {
		// Remove from old parent's children
		if old_parent := hierarchy.parent; old_parent != 0 {
			if old_hierarchy, old_ok := entity_manager.hierarchies[old_parent]; old_ok {
				for i in 0 ..< len(old_hierarchy.children) {
					if old_hierarchy.children[i] == entity {
						ordered_remove(&old_hierarchy.children, i)
						break
					}
				}
				entity_manager.hierarchies[old_parent] = old_hierarchy
			}
		}

		// Update parent
		hierarchy.parent = parent
		entity_manager.hierarchies[entity] = hierarchy

		// Add to new parent's children
		if parent != 0 {
			if parent_hierarchy, parent_ok := entity_manager.hierarchies[parent]; parent_ok {
				append(&parent_hierarchy.children, entity)
				entity_manager.hierarchies[parent] = parent_hierarchy
			}
		}
	}
}

// Get entity parent
ecs_get_parent :: proc(entity: Entity) -> Entity {
	if hierarchy, ok := entity_manager.hierarchies[entity]; ok {
		return hierarchy.parent
	}
	return 0
}

// Get entity children
ecs_get_children :: proc(entity: Entity) -> []Entity {
	if hierarchy, ok := entity_manager.hierarchies[entity]; ok {
		return hierarchy.children[:]
	}
	return nil
}

// Get entity root (top-most parent)
ecs_get_root :: proc(entity: Entity) -> Entity {
	current := entity
	for {
		if parent := ecs_get_parent(current); parent != 0 {
			current = parent
		} else {
			break
		}
	}
	return current
}

// Get entity path (list of entities from root to this entity)
ecs_get_entity_path :: proc(entity: Entity) -> []Entity {
	path: [dynamic]Entity
	current := entity

	// Add all parents to path
	for {
		append(&path, current)
		if parent := ecs_get_parent(current); parent != 0 {
			current = parent
		} else {
			break
		}
	}

	// Reverse the path to get root->entity order
	for i in 0 ..< len(path) / 2 {
		path[i], path[len(path) - 1 - i] = path[len(path) - 1 - i], path[i]
	}

	return path[:]
}

// Check if an entity has a specific component
ecs_has_component :: proc(entity: Entity, type: Component_Type) -> bool {
	if entity == 0 do return false

	#partial switch type {
	case .TRANSFORM:
		return entity in entity_manager.transforms
	case .RENDERER:
		return entity in entity_manager.renderers
	case .CAMERA:
		return entity in entity_manager.cameras
	case .LIGHT:
		return entity in entity_manager.lights
	case .SCRIPT:
		return entity in entity_manager.scripts
	case:
		return false
	}
}

// Get all entities with a specific component
ecs_get_entities_with_component :: proc(type: Component_Type) -> []Entity {
	entities: [dynamic]Entity

	#partial switch type {
	case .TRANSFORM:
		for entity in entity_manager.transforms {
			append(&entities, entity)
		}
	case .RENDERER:
		for entity in entity_manager.renderers {
			append(&entities, entity)
		}
	case .CAMERA:
		for entity in entity_manager.cameras {
			append(&entities, entity)
		}
	case .LIGHT:
		for entity in entity_manager.lights {
			append(&entities, entity)
		}
	case .SCRIPT:
		for entity in entity_manager.scripts {
			append(&entities, entity)
		}
	case:
		return nil
	}

	return entities[:]
}

// Create and add a component to an entity
ecs_create_and_add_component :: proc(entity: Entity, component_type: Component_Type) -> bool {
	if component := create_component(component_type, entity); component != nil {
		ecs_add_component(entity, component)
		return true
	}
	return false
}

// Get a component from an entity
ecs_get_component :: proc(entity: Entity, type: Component_Type) -> ^Component {
	if entity == 0 do return nil

	#partial switch type {
	case .TRANSFORM:
		if transform, ok := entity_manager.transforms[entity]; ok {
			component := new(Transform_Component)
			component^ = transform
			return cast(^Component)component
		}
	case .RENDERER:
		if renderer, ok := entity_manager.renderers[entity]; ok {
			component := new(Renderer)
			component^ = renderer
			return cast(^Component)component
		}
	case .CAMERA:
		if camera, ok := entity_manager.cameras[entity]; ok {
			component := new(Camera)
			component^ = camera
			return cast(^Component)component
		}
	case .LIGHT:
		if light, ok := entity_manager.lights[entity]; ok {
			component := new(Light)
			component^ = light
			return cast(^Component)component
		}
	case .SCRIPT:
		if script, ok := entity_manager.scripts[entity]; ok {
			component := new(Script)
			component^ = script
			return cast(^Component)component
		}
	case:
		return nil
	}
	return nil
}

// Get all components for an entity
ecs_get_components :: proc(entity: Entity, allocator := context.allocator) -> []^Component {
	components: [dynamic]^Component

	// Get transform component
	if transform := ecs_get_component(entity, .TRANSFORM); transform != nil {
		append(&components, transform)
	}

	// Get renderer component
	if renderer := ecs_get_component(entity, .RENDERER); renderer != nil {
		append(&components, renderer)
	}

	// Get camera component
	if camera := ecs_get_component(entity, .CAMERA); camera != nil {
		append(&components, camera)
	}

	// Get light component
	if light := ecs_get_component(entity, .LIGHT); light != nil {
		append(&components, light)
	}

	// Get script component
	if script := ecs_get_component(entity, .SCRIPT); script != nil {
		append(&components, script)
	}

	return slice.clone(components[:])
}

// Get entity name
ecs_get_entity_name :: proc(entity: Entity) -> string {
	if name, ok := entity_manager.names[entity]; ok {
		return name
	}
	return fmt.tprintf("Entity_%d", entity)
}

// Set entity name
ecs_set_entity_name :: proc(entity: Entity, name: string) {
	entity_manager.names[entity] = name
}

// Get entity active state
ecs_is_entity_active :: proc(entity: Entity) -> bool {
	if active, ok := entity_manager.active_states[entity]; ok {
		return active
	}
	return true
}

// Set entity active state
ecs_set_entity_active :: proc(entity: Entity, active: bool) {
	entity_manager.active_states[entity] = active
}

// Get entity tags
ecs_get_entity_tags :: proc(entity: Entity) -> []string {
	if tags, ok := entity_manager.tags[entity]; ok {
		return tags[:]
	}
	return nil
}

// Add tag to entity
ecs_add_entity_tag :: proc(entity: Entity, tag: string) {
	if tags, ok := entity_manager.tags[entity]; ok {
		append(&tags, tag)
	}
}

// Remove tag from entity
ecs_remove_entity_tag :: proc(entity: Entity, tag: string) {
	if tags, ok := entity_manager.tags[entity]; ok {
		for i := 0; i < len(tags); i += 1 {
			if tags[i] == tag {
				ordered_remove(&tags, i)
				break
			}
		}
	}
}

// Add transform component
ecs_add_transform :: proc(
	entity: Entity,
	position: raylib.Vector3 = {0, 0, 0},
	rotation: raylib.Vector3 = {0, 0, 0},
	scale: raylib.Vector3 = {1, 1, 1},
) -> ^Transform_Component {
	if entity == 0 do return nil

	transform := Transform_Component {
		type         = .TRANSFORM,
		entity       = entity,
		enabled      = true,
		position     = position,
		rotation     = rotation,
		scale        = scale,
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}

	entity_manager.transforms[entity] = transform
	component := new(Transform_Component)
	component^ = transform
	return component
}

// Add renderer component
ecs_add_renderer :: proc(entity: Entity) -> ^Renderer {
	if entity == 0 do return nil

	renderer := Renderer {
		type          = .RENDERER,
		entity        = entity,
		enabled       = true,
		visible       = true,
		model_type    = .CUBE,
		mesh_path     = "",
		material_path = "",
	}

	entity_manager.renderers[entity] = renderer
	component := new(Renderer)
	component^ = renderer
	return component
}

// Add camera component
ecs_add_camera :: proc(
	entity: Entity,
	fov: f32 = 45.0,
	near: f32 = 0.1,
	far: f32 = 1000.0,
	is_main: bool = false,
) -> ^Camera {
	if entity == 0 do return nil

	camera := Camera {
		type    = .CAMERA,
		entity  = entity,
		enabled = true,
		fov     = fov,
		near    = near,
		far     = far,
		is_main = is_main,
	}

	entity_manager.cameras[entity] = camera
	component := new(Camera)
	component^ = camera
	return component
}

// Add light component
ecs_add_light :: proc(
	entity: Entity,
	light_type: Light_Type = .POINT,
	color: raylib.Vector3 = {1, 1, 1},
	intensity: f32 = 1.0,
	range: f32 = 10.0,
	spot_angle: f32 = 45.0,
) -> ^Light {
	if entity == 0 do return nil

	light := Light {
		type       = .LIGHT,
		entity     = entity,
		enabled    = true,
		light_type = light_type,
		color      = color,
		intensity  = intensity,
		range      = range,
		spot_angle = spot_angle,
	}

	entity_manager.lights[entity] = light
	component := new(Light)
	component^ = light
	return component
}

// Add script component
ecs_add_script :: proc(entity: Entity, script_name: string = "") -> ^Script {
	if entity == 0 do return nil

	script := Script {
		type        = .SCRIPT,
		entity      = entity,
		enabled     = true,
		script_name = script_name,
	}

	entity_manager.scripts[entity] = script
	component := new(Script)
	component^ = script
	return component
}
