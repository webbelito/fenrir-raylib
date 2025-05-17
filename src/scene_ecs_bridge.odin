package main

import "core:fmt"
import "core:log"
import "core:strings"

// Convert a scene entity to the new ECS world
scene_entity_to_ecs :: proc(entity: Entity) {
	log_info(.ENGINE, "Converting scene entity %d to ECS", entity)

	// Get entity name from scene system
	entity_name := ecs_get_entity_name(entity)

	// Create entity in the new ECS world
	ecs_entity := world_create_entity(entity_name)

	// Map old entity to new entity for reference
	scene_manager.entity_map[entity] = ecs_entity

	// Copy components
	transform := ecs_get_component(entity, Transform)
	if transform != nil {
		world_add_component(ecs_entity, Transform, transform^)
	}

	renderer := ecs_get_component(entity, Renderer)
	if renderer != nil {
		world_add_component(ecs_entity, Renderer, renderer^)
	}

	camera := ecs_get_component(entity, Camera)
	if camera != nil {
		world_add_component(ecs_entity, Camera, camera^)
	}

	light := ecs_get_component(entity, Light)
	if light != nil {
		world_add_component(ecs_entity, Light, light^)
	}

	script := ecs_get_component(entity, Script)
	if script != nil {
		world_add_component(ecs_entity, Script, script^)
	}

	// Handle hierarchy
	parent := ecs_get_entity_parent(entity)
	if parent != 0 {
		if ecs_parent, ok := scene_manager.entity_map[parent]; ok {
			// Set parent in transform component
			if new_transform := world_get_component(ecs_entity, Transform); new_transform != nil {
				transform_set_parent(&global_world.registry, ecs_entity, ecs_parent)
			}
		}
	}
}

// Convert a whole scene to the new ECS world
scene_to_ecs :: proc(scene: ^Scene) {
	// Clear any existing entity mapping
	clear(&scene_manager.entity_map)

	// First convert all entities to ensure they exist
	for entity in scene.entities {
		scene_entity_to_ecs(entity)
	}

	log_info(.ENGINE, "Scene converted to ECS world: %s", scene.name)
}

// Export an entity from the ECS world to the old scene format
ecs_entity_to_scene :: proc(entity: Entity) -> Entity {
	// Create entity in the scene system
	scene_entity := ecs_create_entity()

	// Get entity name from the world
	entity_name := world_get_entity_name(entity)
	ecs_set_entity_name(scene_entity, entity_name)

	// Copy components
	transform := world_get_component(entity, Transform)
	if transform != nil {
		new_transform := ecs_add_transform(scene_entity)
		if new_transform != nil {
			new_transform^ = transform^
		}
	}

	renderer := world_get_component(entity, Renderer)
	if renderer != nil {
		new_renderer := ecs_add_renderer(scene_entity)
		if new_renderer != nil {
			new_renderer^ = renderer^
		}
	}

	camera := world_get_component(entity, Camera)
	if camera != nil {
		new_camera := ecs_add_camera(scene_entity)
		if new_camera != nil {
			new_camera^ = camera^
		}
	}

	light := world_get_component(entity, Light)
	if light != nil {
		new_light := ecs_add_light(scene_entity)
		if new_light != nil {
			new_light^ = light^
		}
	}

	script := world_get_component(entity, Script)
	if script != nil {
		new_script := ecs_add_script(scene_entity)
		if new_script != nil {
			new_script^ = script^
		}
	}

	return scene_entity
}

// Create a scene from the current ECS world state
ecs_to_scene :: proc(name: string) -> ^Scene {
	// Create a new scene
	scene, ok := scene_manager_new(name)
	if !ok {
		log_error(.ENGINE, "Failed to create scene from ECS world")
		return nil
	}

	// Get all entities with Transform components (all visible entities)
	entities := component_registry_view_single(&global_world.registry, Transform)
	defer delete(entities)

	// Step 1: Create all entities first
	for entity in entities {
		scene_entity := ecs_entity_to_scene(entity)
		scene_manager.entity_map_reverse[entity] = scene_entity
	}

	// Step 2: Setup hierarchy
	for entity in entities {
		transform := world_get_component(entity, Transform)
		if transform != nil && transform.parent != 0 {
			if scene_parent, ok := scene_manager.entity_map_reverse[transform.parent]; ok {
				if scene_entity, ok2 := scene_manager.entity_map_reverse[entity]; ok2 {
					// Set parent-child relationship
					ecs_set_entity_parent(scene_entity, scene_parent)
				}
			}
		}
	}

	log_info(.ENGINE, "Created scene from ECS world: %s", name)
	return scene
}

// Initialize scene-ECS bridge
scene_ecs_bridge_init :: proc() {
	// Initialize entity mapping tables
	scene_manager.entity_map = make(map[Entity]Entity)
	scene_manager.entity_map_reverse = make(map[Entity]Entity)
}

// Shutdown scene-ECS bridge
scene_ecs_bridge_shutdown :: proc() {
	delete(scene_manager.entity_map)
	delete(scene_manager.entity_map_reverse)
}

// Helper function to get an entity's parent from the old ECS
// NOTE: This function is now imported from old_ecs_helpers.odin
/*
ecs_get_entity_parent :: proc(entity: Entity) -> Entity {
	if transform := ecs_get_component(entity, Transform); transform != nil {
		return transform.parent
	}
	return 0
}
*/

// Helper function to set entity-parent relationship in the old ECS
// NOTE: This function is now imported from old_ecs_helpers.odin
/*
ecs_set_entity_parent :: proc(entity: Entity, parent: Entity) -> bool {
	transform := ecs_get_component(entity, Transform)
	if transform == nil {
		return false
	}
	transform.parent = parent
	transform.dirty = true
	return true
}
*/
