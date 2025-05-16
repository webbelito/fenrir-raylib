package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:time"
import raylib "vendor:raylib"

// Entity is just an ID
Entity :: distinct u64

// Sparse set implementation for component storage
Sparse_Set :: struct($T: typeid) {
	dense:     [dynamic]T, // Dense array of components
	sparse:    map[Entity]int, // Maps entity to index in dense array
	free_list: [dynamic]Entity, // List of free entity slots
}

// Registry manages all entities and their components
Registry :: struct {
	entities:       map[Entity]bool, // Active entities
	next_entity_id: Entity, // Next available entity ID
	names:          map[Entity]string, // Entity names
	active_states:  map[Entity]bool, // Entity active states
	tags:           map[Entity][dynamic]string, // Entity tags
	hierarchies:    map[Entity]Entity_Hierarchy, // Parent-child relationships

	// Component storage
	transforms:     Sparse_Set(Transform),
	renderers:      Sparse_Set(Renderer),
	cameras:        Sparse_Set(Camera),
	lights:         Sparse_Set(Light),
	scripts:        Sparse_Set(Script),
}

// Entity hierarchy data
Entity_Hierarchy :: struct {
	parent:   Entity,
	children: [dynamic]Entity,
}

// Global registry instance
registry: Registry

// Initialize a sparse set
ecs_init_sparse_set :: proc(set: ^Sparse_Set($T)) {
	set.dense = make([dynamic]T)
	set.sparse = make(map[Entity]int)
	set.free_list = make([dynamic]Entity)
}

// Destroy a sparse set
ecs_destroy_sparse_set :: proc(set: ^Sparse_Set($T)) {
	delete(set.dense)
	clear(&set.sparse)
	delete(set.free_list)
}

// Initialize the registry
ecs_init :: proc() {
	log_info(.ENGINE, "Initializing registry")
	registry = Registry {
		entities       = make(map[Entity]bool),
		next_entity_id = 1,
		names          = make(map[Entity]string),
		active_states  = make(map[Entity]bool),
		tags           = make(map[Entity][dynamic]string),
		hierarchies    = make(map[Entity]Entity_Hierarchy),
	}

	ecs_init_sparse_set(&registry.transforms)
	ecs_init_sparse_set(&registry.renderers)
	ecs_init_sparse_set(&registry.cameras)
	ecs_init_sparse_set(&registry.lights)
	ecs_init_sparse_set(&registry.scripts)

	log_info(.ENGINE, "Registry initialized")
}

// Destroy the registry
ecs_destroy :: proc() {
	log_info(.ENGINE, "Destroying registry")

	ecs_destroy_sparse_set(&registry.transforms)
	ecs_destroy_sparse_set(&registry.renderers)
	ecs_destroy_sparse_set(&registry.cameras)
	ecs_destroy_sparse_set(&registry.lights)
	ecs_destroy_sparse_set(&registry.scripts)

	delete(registry.entities)
	delete(registry.names)
	delete(registry.active_states)

	// Clean up tags
	for _, &tags in registry.tags {
		clear(&tags)
	}
	delete(registry.tags)

	// Clean up hierarchies
	for _, &hierarchy in registry.hierarchies {
		clear(&hierarchy.children)
	}
	delete(registry.hierarchies)

	log_info(.ENGINE, "Registry destroyed")
}

// Create a new entity
ecs_create_entity :: proc() -> Entity {
	entity := registry.next_entity_id
	registry.next_entity_id += 1
	registry.entities[entity] = true

	// Set default name
	registry.names[entity] = fmt.tprintf("Entity_%d", entity)

	// Set default active state
	registry.active_states[entity] = true

	// Initialize empty tags array
	registry.tags[entity] = make([dynamic]string)

	// Initialize hierarchy
	registry.hierarchies[entity] = Entity_Hierarchy {
		parent   = 0,
		children = make([dynamic]Entity),
	}

	return entity
}

// Destroy an entity and all its components
ecs_destroy_entity :: proc(entity: Entity) {
	if !(entity in registry.entities) do return

	// First, destroy all children recursively
	if hierarchy, ok := registry.hierarchies[entity]; ok {
		for child in hierarchy.children {
			ecs_destroy_entity(child)
		}
		clear(&hierarchy.children)
	}

	// Remove from parent's children
	if hierarchy, ok := registry.hierarchies[entity]; ok {
		if parent := hierarchy.parent; parent != 0 {
			if parent_hierarchy, parent_ok := registry.hierarchies[parent]; parent_ok {
				for i in 0 ..< len(parent_hierarchy.children) {
					if parent_hierarchy.children[i] == entity {
						ordered_remove(&parent_hierarchy.children, i)
						break
					}
				}
				registry.hierarchies[parent] = parent_hierarchy
			}
		}
	}

	// Remove all components
	ecs_remove_component(entity, Transform)
	ecs_remove_component(entity, Renderer)
	ecs_remove_component(entity, Camera)
	ecs_remove_component(entity, Light)
	ecs_remove_component(entity, Script)

	// Remove entity metadata
	delete_key(&registry.entities, entity)
	delete_key(&registry.names, entity)
	delete_key(&registry.active_states, entity)
	if tags, ok := registry.tags[entity]; ok {
		clear(&tags)
		delete_key(&registry.tags, entity)
	}
	if hierarchy, ok := registry.hierarchies[entity]; ok {
		clear(&hierarchy.children)
		delete_key(&registry.hierarchies, entity)
	}
}

// Add a component to an entity
ecs_add_component :: proc(entity: Entity, $T: typeid, component: T) -> ^T {
	if !(entity in registry.entities) do return nil

	set := ecs_get_component_set(T)
	if set == nil do return nil

	// Check if entity already has this component
	if entity in set.sparse do return nil

	// Add component to dense array
	append(&set.dense, component)
	set.sparse[entity] = len(set.dense) - 1

	return &set.dense[len(set.dense) - 1]
}

// Get a component from an entity
ecs_get_component :: proc(entity: Entity, $T: typeid) -> ^T {
	if !(entity in registry.entities) do return nil

	set := ecs_get_component_set(T)
	if set == nil do return nil

	if idx, ok := set.sparse[entity]; ok {
		return &set.dense[idx]
	}

	return nil
}

// Remove a component from an entity
ecs_remove_component :: proc(entity: Entity, $T: typeid) {
	if !(entity in registry.entities) do return

	set := ecs_get_component_set(T)
	if set == nil do return

	if idx, ok := set.sparse[entity]; ok {
		// Swap with last element
		last_idx := len(set.dense) - 1
		if idx != last_idx {
			set.dense[idx] = set.dense[last_idx]
			// Update sparse map for swapped entity
			for e, i in set.sparse {
				if i == last_idx {
					set.sparse[e] = idx
					break
				}
			}
		}

		// Remove last element
		pop(&set.dense)
		delete_key(&set.sparse, entity)
	}
}

// Check if an entity has a component
ecs_has_component :: proc(entity: Entity, $T: typeid) -> bool {
	if !(entity in registry.entities) do return false

	set := ecs_get_component_set(T)
	if set == nil do return false

	return entity in set.sparse
}

// Get the component set for a type
ecs_get_component_set :: proc($T: typeid) -> ^Sparse_Set(T) {
	when T == Transform {
		return &registry.transforms
	} else when T == Renderer {
		return &registry.renderers
	} else when T == Camera {
		return &registry.cameras
	} else when T == Light {
		return &registry.lights
	} else when T == Script {
		return &registry.scripts
	} else {
		return nil
	}
}

// Query entities with specific components
ecs_query :: proc($T: typeid) -> []Entity {
	set := ecs_get_component_set(T)
	if set == nil do return nil

	result := make([dynamic]Entity)
	for entity in set.sparse {
		append(&result, entity)
	}

	return result[:]
}

// Query entities with multiple components
ecs_query_multi :: proc($T1: typeid, $T2: typeid) -> []Entity {
	set1 := ecs_get_component_set(T1)
	set2 := ecs_get_component_set(T2)
	if set1 == nil || set2 == nil do return nil

	result := make([dynamic]Entity)
	for entity in set1.sparse {
		if entity in set2.sparse {
			append(&result, entity)
		}
	}

	return result[:]
}

// Set entity parent
ecs_set_parent :: proc(entity: Entity, parent: Entity) {
	if entity == 0 || entity == parent {
		return
	}

	// Get current hierarchy
	if hierarchy, ok := registry.hierarchies[entity]; ok {
		// Remove from old parent's children
		if old_parent := hierarchy.parent; old_parent != 0 {
			if old_hierarchy, old_ok := registry.hierarchies[old_parent]; old_ok {
				for i in 0 ..< len(old_hierarchy.children) {
					if old_hierarchy.children[i] == entity {
						ordered_remove(&old_hierarchy.children, i)
						break
					}
				}
				registry.hierarchies[old_parent] = old_hierarchy
			}
		}

		// Update parent
		hierarchy.parent = parent
		registry.hierarchies[entity] = hierarchy

		// Add to new parent's children
		if parent != 0 {
			if parent_hierarchy, parent_ok := registry.hierarchies[parent]; parent_ok {
				append(&parent_hierarchy.children, entity)
				registry.hierarchies[parent] = parent_hierarchy
			}
		}
	}
}

// Get entity parent
ecs_get_parent :: proc(entity: Entity) -> Entity {
	if hierarchy, ok := registry.hierarchies[entity]; ok {
		return hierarchy.parent
	}
	return 0
}

// Get entity children
ecs_get_children :: proc(entity: Entity) -> []Entity {
	if hierarchy, ok := registry.hierarchies[entity]; ok {
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

// Get entity name
ecs_get_entity_name :: proc(entity: Entity) -> string {
	if name, ok := registry.names[entity]; ok {
		return name
	}
	return fmt.tprintf("Entity_%d", entity)
}

// Set entity name
ecs_set_entity_name :: proc(entity: Entity, name: string) {
	registry.names[entity] = name
}

// Get entity active state
ecs_is_entity_active :: proc(entity: Entity) -> bool {
	if active, ok := registry.active_states[entity]; ok {
		return active
	}
	return true
}

// Set entity active state
ecs_set_entity_active :: proc(entity: Entity, active: bool) {
	registry.active_states[entity] = active
}

// Get entity tags
ecs_get_entity_tags :: proc(entity: Entity) -> []string {
	if tags, ok := registry.tags[entity]; ok {
		return tags[:]
	}
	return nil
}

// Add tag to entity
ecs_add_entity_tag :: proc(entity: Entity, tag: string) {
	if tags, ok := registry.tags[entity]; ok {
		append(&tags, tag)
	}
}

// Remove tag from entity
ecs_remove_entity_tag :: proc(entity: Entity, tag: string) {
	if tags, ok := registry.tags[entity]; ok {
		for i := 0; i < len(tags); i += 1 {
			if tags[i] == tag {
				ordered_remove(&tags, i)
				break
			}
		}
	}
}

// Helper functions for common component operations
ecs_add_transform :: proc(
	entity: Entity,
	position: raylib.Vector3 = {0, 0, 0},
	rotation: raylib.Vector3 = {0, 0, 0},
	scale: raylib.Vector3 = {1, 1, 1},
) -> ^Transform {
	transform := Transform {
		position     = position,
		rotation     = rotation,
		scale        = scale,
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		dirty        = true,
	}
	return ecs_add_component(entity, Transform, transform)
}

ecs_add_renderer :: proc(entity: Entity) -> ^Renderer {
	renderer := Renderer {
		visible       = true,
		model_type    = .CUBE,
		mesh_path     = "cube",
		material_path = "default",
	}
	return ecs_add_component(entity, Renderer, renderer)
}

ecs_add_camera :: proc(
	entity: Entity,
	fov: f32 = 45.0,
	near: f32 = 0.1,
	far: f32 = 1000.0,
	is_main: bool = false,
) -> ^Camera {
	camera := Camera {
		fov     = fov,
		near    = near,
		far     = far,
		is_main = is_main,
	}
	return ecs_add_component(entity, Camera, camera)
}

ecs_add_light :: proc(
	entity: Entity,
	light_type: Light_Type = .POINT,
	color: raylib.Vector3 = {1, 1, 1},
	intensity: f32 = 1.0,
	range: f32 = 10.0,
	spot_angle: f32 = 45.0,
) -> ^Light {
	light := Light {
		light_type = light_type,
		color      = color,
		intensity  = intensity,
		range      = range,
		spot_angle = spot_angle,
	}
	return ecs_add_component(entity, Light, light)
}

ecs_add_script :: proc(entity: Entity, script_name: string = "") -> ^Script {
	script := Script {
		script_name = script_name,
	}
	return ecs_add_component(entity, Script, script)
}
