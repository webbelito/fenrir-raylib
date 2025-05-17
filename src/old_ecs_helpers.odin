package main

// These functions help bridge between the old ECS system and the new one
// NOTE: This file contains the original implementations of these functions.
// During refactoring, some of these functions might be duplicated in other files.
// When the refactoring is complete, the duplicates should be removed.

// Add a transform component to an entity
ecs_add_transform :: proc(entity: Entity) -> ^Transform {
	transform := transform_create()
	return ecs_add_component(entity, Transform, transform)
}

// Add a renderer component to an entity
ecs_add_renderer :: proc(entity: Entity) -> ^Renderer {
	renderer := renderer_create()
	return ecs_add_component(entity, Renderer, renderer)
}

// Add a camera component to an entity
ecs_add_camera :: proc(entity: Entity) -> ^Camera {
	camera := camera_create()
	return ecs_add_component(entity, Camera, camera)
}

// Add a light component to an entity
ecs_add_light :: proc(entity: Entity) -> ^Light {
	light := light_create_directional()
	return ecs_add_component(entity, Light, light)
}

// Add a script component to an entity
ecs_add_script :: proc(entity: Entity) -> ^Script {
	script := Script {
		script_name = "",
	}
	return ecs_add_component(entity, Script, script)
}

// Get component name
ecs_get_component_name :: proc($T: typeid) -> string {
	#partial switch typeid_of(T) {
	case typeid_of(Transform):
		return "Transform"
	case typeid_of(Renderer):
		return "Renderer"
	case typeid_of(Camera):
		return "Camera"
	case typeid_of(Light):
		return "Light"
	case typeid_of(Script):
		return "Script"
	}
	return "Unknown"
}

// Query entities with a specific component type
// NOTE: This function is redeclared in entity_manager.odin and will be removed during refactoring
/*
ecs_query :: proc($T: typeid, allocator := context.allocator) -> []Entity {
	result := make([dynamic]Entity, allocator)

	// Iterate through all entities and check for the component
	for entity in scene_manager.current_scene.entities {
		if ecs_has_component(entity, T) {
			append(&result, entity)
		}
	}

	return result[:]
}
*/

// Helper function to get an entity's parent
ecs_get_entity_parent :: proc(entity: Entity) -> Entity {
	if transform := ecs_get_component(entity, Transform); transform != nil {
		return transform.parent
	}
	return 0
}

// Helper function to set entity-parent relationship
ecs_set_entity_parent :: proc(entity: Entity, parent: Entity) -> bool {
	transform := ecs_get_component(entity, Transform)
	if transform == nil {
		return false
	}

	transform.parent = parent
	transform.dirty = true
	return true
}
