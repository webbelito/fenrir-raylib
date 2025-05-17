package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import "core:time"

// World ties together the component registry and system manager
World :: struct {
	registry:         Component_Registry,
	systems:          System_Manager,
	next_entity_id:   Entity,
	entity_names:     map[Entity]string,
	entity_active:    map[Entity]bool,

	// Default systems
	transform_system: System,
	render_system:    System,
}

global_world: World

// Initialize the world
world_init :: proc() {
	log_info(.ENGINE, "Initializing world")

	// Initialize component registry
	global_world.registry = component_registry_init()

	// Initialize system manager
	global_world.systems = system_manager_init()

	// Initialize entity tracking
	global_world.next_entity_id = 1
	global_world.entity_names = make(map[Entity]string)
	global_world.entity_active = make(map[Entity]bool)

	// Register default systems
	global_world.transform_system = transform_system_create()
	system_manager_register(&global_world.systems, global_world.transform_system)

	global_world.render_system = render_system_create()
	system_manager_register(&global_world.systems, global_world.render_system)

	// Initialize all systems
	system_manager_initialize_all(&global_world.systems, &global_world.registry)

	log_info(.ENGINE, "World initialized successfully")
}

// Destroy the world
world_destroy :: proc() {
	log_info(.ENGINE, "Destroying world")

	// Shutdown all systems
	system_manager_shutdown_all(&global_world.systems, &global_world.registry)

	// Destroy system manager
	system_manager_destroy(&global_world.systems)

	// Destroy component registry
	component_registry_destroy(&global_world.registry)

	// Clean up entity tracking
	delete(global_world.entity_names)
	delete(global_world.entity_active)

	log_info(.ENGINE, "World destroyed successfully")
}

// Update the world
world_update :: proc(dt: f32) {
	// Update all systems
	system_manager_update_all(&global_world.systems, &global_world.registry, dt)
}

// Fixed update of the world
world_fixed_update :: proc(fixed_dt: f32) {
	// Run fixed update on all systems
	system_manager_fixed_update_all(&global_world.systems, &global_world.registry, fixed_dt)
}

// Create a new entity
world_create_entity :: proc(name: string = "") -> Entity {
	entity_id := global_world.next_entity_id
	global_world.next_entity_id += 1

	// Set entity name
	if name == "" {
		global_world.entity_names[entity_id] = fmt.tprintf("Entity_%d", entity_id)
	} else {
		global_world.entity_names[entity_id] = strings.clone(name)
	}

	// Set entity active
	global_world.entity_active[entity_id] = true

	return entity_id
}

// Destroy an entity
world_destroy_entity :: proc(entity: Entity) {
	// Remove all components
	component_registry_remove_all(&global_world.registry, entity)

	// Clean up entity name
	if name, has_name := global_world.entity_names[entity]; has_name {
		if name != fmt.tprintf("Entity_%d", entity) {
			delete(name)
		}
		delete_key(&global_world.entity_names, entity)
	}

	// Remove active state
	delete_key(&global_world.entity_active, entity)
}

// Set entity name
world_set_entity_name :: proc(entity: Entity, name: string) {
	if old_name, has_name := global_world.entity_names[entity]; has_name {
		if old_name != fmt.tprintf("Entity_%d", entity) {
			delete(old_name)
		}
	}

	global_world.entity_names[entity] = strings.clone(name)
}

// Get entity name
world_get_entity_name :: proc(entity: Entity) -> string {
	if name, has_name := global_world.entity_names[entity]; has_name {
		return name
	}
	return fmt.tprintf("Entity_%d", entity)
}

// Set entity active state
world_set_entity_active :: proc(entity: Entity, active: bool) {
	global_world.entity_active[entity] = active
}

// Get entity active state
world_get_entity_active :: proc(entity: Entity) -> bool {
	if active, has_active := global_world.entity_active[entity]; has_active {
		return active
	}
	return false
}

// Add a component to an entity
world_add_component :: proc(entity: Entity, $T: typeid, component: T) -> ^T {
	return component_registry_add(&global_world.registry, entity, T, component)
}

// Get a component from an entity
world_get_component :: proc(entity: Entity, $T: typeid) -> ^T {
	return component_registry_get(&global_world.registry, entity, T)
}

// Remove a component from an entity
world_remove_component :: proc(entity: Entity, $T: typeid) {
	component_registry_remove(&global_world.registry, entity, T)
}

// Check if entity has component
world_has_component :: proc(entity: Entity, $T: typeid) -> bool {
	return component_registry_has(&global_world.registry, entity, T)
}

// Get all entities with a specific component
world_get_entities_with :: proc(
	registry: ^Component_Registry,
	$T: typeid,
	allocator := context.allocator,
) -> []Entity {
	return component_registry_view_single(registry, T, allocator)
}
