package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"
import "core:slice"

// Entity is just an ID
Entity :: distinct u64

// Component_Type is an enum of all component types
Component_Type :: enum {
	TRANSFORM,
	RENDERER,
	CAMERA,
	SCRIPT,
	LIGHT,
	COLLIDER,
	RIGIDBODY,
	AUDIO_SOURCE,
	// Add more component types as needed
}

// Basic component interface
Component :: struct {
	type:    Component_Type,
	entity:  Entity,
	enabled: bool,
}

// Transform component
Transform :: struct {
	using base: Component,
	position:   [3]f32,
	rotation:   [3]f32,
	scale:      [3]f32,
}

// Renderer component
Renderer :: struct {
	using base: Component,
	mesh:       string, // Path to mesh
	material:   string, // Path to material
	visible:    bool,
}

// Camera component
Camera :: struct {
	using base: Component,
	fov:        f32,
	near:       f32,
	far:        f32,
	is_main:    bool,
}

// Light types
Light_Type :: enum {
	DIRECTIONAL,
	POINT,
	SPOT,
}

// Light component
Light :: struct {
	using base: Component,
	light_type: Light_Type,
	color:      [3]f32,
	intensity:  f32,
	range:      f32,
	spot_angle: f32, // Only for spot lights
}

// Script component
Script :: struct {
	using base:  Component,
	script_name: string,
	// In a real implementation, this would have references to script instances
}

// Entity_Manager manages all entities and components
Entity_Manager :: struct {
	next_entity_id: Entity,
	transforms:     map[Entity]Transform,
	renderers:      map[Entity]Renderer,
	cameras:        map[Entity]Camera,
	lights:         map[Entity]Light,
	scripts:        map[Entity]Script,
	// Add more component collections as needed
}

entity_manager: Entity_Manager

// Initialize the entity manager
ecs_init :: proc() {
	log_info(.ENGINE, "Initializing ECS system")

	entity_manager.next_entity_id = 1
	entity_manager.transforms = make(map[Entity]Transform)
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

// Add a transform component to an entity
ecs_add_transform :: proc(entity: Entity, position, rotation, scale: [3]f32) -> ^Transform {
	transform := Transform {
		base = Component{type = .TRANSFORM, entity = entity, enabled = true},
		position = position,
		rotation = rotation,
		scale = scale,
	}

	entity_manager.transforms[entity] = transform
	return &entity_manager.transforms[entity]
}

// Add a renderer component to an entity
ecs_add_renderer :: proc(entity: Entity, mesh, material: string) -> ^Renderer {
	renderer := Renderer {
		base = Component{type = .RENDERER, entity = entity, enabled = true},
		mesh = mesh,
		material = material,
		visible = true,
	}

	entity_manager.renderers[entity] = renderer
	return &entity_manager.renderers[entity]
}

// Add a camera component to an entity
ecs_add_camera :: proc(entity: Entity, fov, near, far: f32, is_main: bool) -> ^Camera {
	camera := Camera {
		base = Component{type = .CAMERA, entity = entity, enabled = true},
		fov = fov,
		near = near,
		far = far,
		is_main = is_main,
	}

	entity_manager.cameras[entity] = camera
	return &entity_manager.cameras[entity]
}

// Add a light component to an entity
ecs_add_light :: proc(
	entity: Entity,
	light_type: Light_Type,
	color: [3]f32,
	intensity, range: f32,
) -> ^Light {
	light := Light {
		base = Component{type = .LIGHT, entity = entity, enabled = true},
		light_type = light_type,
		color = color,
		intensity = intensity,
		range = range,
		spot_angle = 45.0, // Default spot angle
	}

	entity_manager.lights[entity] = light
	return &entity_manager.lights[entity]
}

// Get a transform component from an entity
ecs_get_transform :: proc(entity: Entity) -> ^Transform {
	if transform, ok := &entity_manager.transforms[entity]; ok {
		return transform
	}
	return nil
}

// Get a renderer component from an entity
ecs_get_renderer :: proc(entity: Entity) -> ^Renderer {
	if renderer, ok := &entity_manager.renderers[entity]; ok {
		return renderer
	}
	return nil
}

// Get a camera component from an entity
ecs_get_camera :: proc(entity: Entity) -> ^Camera {
	if camera, ok := &entity_manager.cameras[entity]; ok {
		return camera
	}
	return nil
}

// Get a light component from an entity
ecs_get_light :: proc(entity: Entity) -> ^Light {
	if light, ok := &entity_manager.lights[entity]; ok {
		return light
	}
	return nil
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

// Get all entities that have a specific component
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

// Get all entities with both component types
ecs_get_entities_with_components :: proc(
	type1, type2: Component_Type,
	allocator := context.allocator,
) -> []Entity {
	entities1 := ecs_get_entities_with_component(type1, allocator)
	defer delete(entities1)

	result: [dynamic]Entity

	for entity in entities1 {
		if ecs_has_component(entity, type2) {
			append(&result, entity)
		}
	}

	return slice.clone(result[:])
}

// Add a component to an entity
ecs_add_component :: proc(entity: Entity, component: ^Component) {
	switch component.type {
	case .TRANSFORM:
		entity_manager.transforms[entity] = (cast(^Transform)component)^
	case .RENDERER:
		entity_manager.renderers[entity] = (cast(^Renderer)component)^
	case .CAMERA:
		entity_manager.cameras[entity] = (cast(^Camera)component)^
	case .LIGHT:
		entity_manager.lights[entity] = (cast(^Light)component)^
	case .SCRIPT:
		entity_manager.scripts[entity] = (cast(^Script)component)^
	case .COLLIDER, .RIGIDBODY, .AUDIO_SOURCE:
		// These components are not yet implemented
		break
	}
}

// Get all entities with renderer components
ecs_get_renderers :: proc() -> map[Entity]^Renderer {
	renderers := make(map[Entity]^Renderer)
	for entity in 1 ..< entity_manager.next_entity_id {
		if ecs_has_component(entity, .RENDERER) {
			renderer := ecs_get_renderer(entity)
			if renderer != nil {
				renderers[entity] = renderer
			}
		}
	}
	return renderers
}
