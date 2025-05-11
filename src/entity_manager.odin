package main

import "core:fmt"
import "core:log"
import "core:slice"
import "core:strings"

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
}

entity_manager: Entity_Manager

// Initialize the entity manager
entity_manager_init :: proc() {
	log_info(.ENGINE, "Initializing ECS system")

	entity_manager.next_entity_id = 1
	entity_manager.transforms = make(map[Entity]Transform_Component)
	entity_manager.renderers = make(map[Entity]Renderer)
	entity_manager.cameras = make(map[Entity]Camera)
	entity_manager.lights = make(map[Entity]Light)
	entity_manager.scripts = make(map[Entity]Script)
	entity_manager.names = make(map[Entity]string)
	entity_manager.active_states = make(map[Entity]bool)
	entity_manager.tags = make(map[Entity][dynamic]string)
}

// Shutdown the entity manager
entity_manager_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down ECS system")

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
	log_info(.ENGINE, "Entity manager shut down")
}

// Create a new entity
ecs_create_entity :: proc(name: string = "") -> Entity {
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

	return entity
}

// Destroy an entity and all its components
ecs_destroy_entity :: proc(entity: Entity) {
	delete_key(&entity_manager.transforms, entity)
	delete_key(&entity_manager.renderers, entity)
	delete_key(&entity_manager.cameras, entity)
	delete_key(&entity_manager.lights, entity)
	delete_key(&entity_manager.scripts, entity)
	delete_key(&entity_manager.names, entity)
	delete_key(&entity_manager.active_states, entity)
	delete_key(&entity_manager.tags, entity)
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
