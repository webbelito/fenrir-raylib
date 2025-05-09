package main

import "core:fmt"
import "core:log"
import "core:slice"

// Entity manager
Entity_Manager :: struct {
	next_entity_id: Entity,
	transforms:     map[Entity]Transform_Component,
	renderers:      map[Entity]Renderer,
	cameras:        map[Entity]Camera,
	lights:         map[Entity]Light,
	scripts:        map[Entity]Script,
}

entity_manager: Entity_Manager

// Initialize the entity manager
ecs_init :: proc() {
	log_info(.ENGINE, "Initializing ECS system")

	entity_manager.next_entity_id = 1
	entity_manager.transforms = make(map[Entity]Transform_Component)
	entity_manager.renderers = make(map[Entity]Renderer)
	entity_manager.cameras = make(map[Entity]Camera)
	entity_manager.lights = make(map[Entity]Light)
	entity_manager.scripts = make(map[Entity]Script)
}

// Shutdown the entity manager
ecs_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down ECS system")

	delete(entity_manager.transforms)
	delete(entity_manager.renderers)
	delete(entity_manager.cameras)
	delete(entity_manager.lights)
	delete(entity_manager.scripts)
}

// Create a new entity
ecs_create_entity :: proc() -> Entity {
	entity := entity_manager.next_entity_id
	entity_manager.next_entity_id += 1
	return entity
}

// Destroy an entity and all its components
ecs_destroy_entity :: proc(entity: Entity) {
	delete_key(&entity_manager.transforms, entity)
	delete_key(&entity_manager.renderers, entity)
	delete_key(&entity_manager.cameras, entity)
	delete_key(&entity_manager.lights, entity)
	delete_key(&entity_manager.scripts, entity)
}

// Check if an entity has a specific component
ecs_has_component :: proc(entity: Entity, component_type: Component_Type) -> bool {
	#partial switch component_type {
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
ecs_get_entities_with_component :: proc(
	component_type: Component_Type,
	allocator := context.allocator,
) -> []Entity {
	entities: [dynamic]Entity

	#partial switch component_type {
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
	// Unknown component type
	}

	return slice.clone(entities[:])
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
ecs_get_component :: proc(entity: Entity, component_type: Component_Type) -> ^Component {
	#partial switch component_type {
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
	// Unknown component type
	}
	return nil
}

// Remove a component from an entity
ecs_remove_component :: proc(entity: Entity, component_type: Component_Type) {
	#partial switch component_type {
	case .TRANSFORM:
		delete_key(&entity_manager.transforms, entity)
	case .RENDERER:
		delete_key(&entity_manager.renderers, entity)
	case .CAMERA:
		delete_key(&entity_manager.cameras, entity)
	case .LIGHT:
		delete_key(&entity_manager.lights, entity)
	case .SCRIPT:
		delete_key(&entity_manager.scripts, entity)
	case:
	// Unknown component type
	}
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
