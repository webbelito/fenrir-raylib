package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Entity is just an ID
Entity :: distinct u64

// Component base type
Component :: struct {
	type:    Component_Type,
	entity:  Entity,
	enabled: bool,
}

// Component types
Component_Type :: enum {
	TRANSFORM,
	RENDERER,
	CAMERA,
	LIGHT,
	SCRIPT,
	COLLIDER,
	RIGIDBODY,
	AUDIO_SOURCE,
}

// Component data for serialization
Component_Data :: union {
	Transform_Component,
	Renderer,
	Camera,
	Light,
	Script,
}

// Component interface procedures
Component_Interface :: struct {
	init:             proc(_: ^Component, _: Entity) -> bool,
	update:           proc(_: ^Component, _: f32),
	render_inspector: proc(_: ^Component),
	cleanup:          proc(_: ^Component),
	serialize:        proc(_: ^Component) -> Component_Data,
	deserialize:      proc(_: Component_Data, _: Entity) -> ^Component,
}

// Component registry to store component interfaces
component_registry: map[Component_Type]Component_Interface

// Initialize the component system
component_system_init :: proc() {
	log_info(.ENGINE, "Initializing component system")

	// Initialize component registry
	component_registry = make(map[Component_Type]Component_Interface)

	// Register transform component
	component_registry[.TRANSFORM] = Component_Interface {
		init = proc(component: ^Component, entity: Entity) -> bool {
			transform := cast(^Transform_Component)component
			if transform == nil do return false
			transform.type = .TRANSFORM
			transform.entity = entity
			transform.enabled = true
			transform.position = {0, 0, 0}
			transform.rotation = {0, 0, 0}
			transform.scale = {1, 1, 1}
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Transform-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			transform := cast(^Transform_Component)component
			if transform == nil do return
			// Transform-specific inspector rendering
		},
		cleanup = proc(component: ^Component) {
			// Transform-specific cleanup
		},
		serialize = proc(component: ^Component) -> Component_Data {
			transform := cast(^Transform_Component)component
			return transform^
		},
		deserialize = proc(data: Component_Data, entity: Entity) -> ^Component {
			transform := data.(Transform_Component)
			return ecs_add_transform(
				entity,
				transform.position,
				transform.rotation,
				transform.scale,
			)
		},
	}

	// Register renderer component
	component_registry[.RENDERER] = Component_Interface {
		init = proc(component: ^Component, entity: Entity) -> bool {
			renderer := cast(^Renderer)component
			if renderer == nil do return false
			renderer.type = .RENDERER
			renderer.entity = entity
			renderer.enabled = true
			renderer.visible = true
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Renderer-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			renderer := cast(^Renderer)component
			if renderer == nil do return
			// Renderer-specific inspector rendering
		},
		cleanup = proc(component: ^Component) {
			// Renderer-specific cleanup
		},
		serialize = proc(component: ^Component) -> Component_Data {
			renderer := cast(^Renderer)component
			return renderer^
		},
		deserialize = proc(data: Component_Data, entity: Entity) -> ^Component {
			renderer := data.(Renderer)
			return ecs_add_renderer(entity, renderer.mesh, renderer.material)
		},
	}

	// Register camera component
	component_registry[.CAMERA] = Component_Interface {
		init = proc(component: ^Component, entity: Entity) -> bool {
			camera := cast(^Camera)component
			if camera == nil do return false
			camera.type = .CAMERA
			camera.entity = entity
			camera.enabled = true
			camera.fov = 45.0
			camera.near = 0.1
			camera.far = 1000.0
			camera.is_main = false
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Camera-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			camera := cast(^Camera)component
			if camera == nil do return
			// Camera-specific inspector rendering
		},
		cleanup = proc(component: ^Component) {
			// Camera-specific cleanup
		},
		serialize = proc(component: ^Component) -> Component_Data {
			camera := cast(^Camera)component
			return camera^
		},
		deserialize = proc(data: Component_Data, entity: Entity) -> ^Component {
			camera := data.(Camera)
			return ecs_add_camera(entity, camera.fov, camera.near, camera.far, camera.is_main)
		},
	}

	// Register light component
	component_registry[.LIGHT] = Component_Interface {
		init = proc(component: ^Component, entity: Entity) -> bool {
			light := cast(^Light)component
			if light == nil do return false
			light.type = .LIGHT
			light.entity = entity
			light.enabled = true
			light.light_type = .POINT
			light.color = {1, 1, 1}
			light.intensity = 1.0
			light.range = 10.0
			light.spot_angle = 45.0
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Light-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			light := cast(^Light)component
			if light == nil do return
			// Light-specific inspector rendering
		},
		cleanup = proc(component: ^Component) {
			// Light-specific cleanup
		},
		serialize = proc(component: ^Component) -> Component_Data {
			light := cast(^Light)component
			return light^
		},
		deserialize = proc(data: Component_Data, entity: Entity) -> ^Component {
			light := data.(Light)
			return ecs_add_light(
				entity,
				light.light_type,
				light.color,
				light.intensity,
				light.range,
				light.spot_angle,
			)
		},
	}

	// Register script component
	component_registry[.SCRIPT] = Component_Interface {
		init = proc(component: ^Component, entity: Entity) -> bool {
			script := cast(^Script)component
			if script == nil do return false
			script.type = .SCRIPT
			script.entity = entity
			script.enabled = true
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Script-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			script := cast(^Script)component
			if script == nil do return
			// Script-specific inspector rendering
		},
		cleanup = proc(component: ^Component) {
			// Script-specific cleanup
		},
		serialize = proc(component: ^Component) -> Component_Data {
			script := cast(^Script)component
			return script^
		},
		deserialize = proc(data: Component_Data, entity: Entity) -> ^Component {
			script := data.(Script)
			return ecs_add_script(entity, script.script_name)
		},
	}

	log_info(.ENGINE, "Component system initialized")
}

// Shutdown the component system
component_system_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down component system")
	delete(component_registry)
}

// Create a new component of the specified type
create_component :: proc(type: Component_Type, entity: Entity) -> ^Component {
	if interface, ok := component_registry[type]; ok {
		#partial switch type {
		case .TRANSFORM:
			component := new(Transform_Component)
			if interface.init(cast(^Component)component, entity) {
				return cast(^Component)component
			}
			free(component)
		case .RENDERER:
			component := new(Renderer)
			if interface.init(cast(^Component)component, entity) {
				return cast(^Component)component
			}
			free(component)
		case .CAMERA:
			component := new(Camera)
			if interface.init(cast(^Component)component, entity) {
				return cast(^Component)component
			}
			free(component)
		case .LIGHT:
			component := new(Light)
			if interface.init(cast(^Component)component, entity) {
				return cast(^Component)component
			}
			free(component)
		case .SCRIPT:
			component := new(Script)
			if interface.init(cast(^Component)component, entity) {
				return cast(^Component)component
			}
			free(component)
		case:
			log_error(.ENGINE, "Unknown component type: %v", type)
		}
	}
	return nil
}

// Add a component to an entity
ecs_add_component :: proc(entity: Entity, component: ^Component) {
	if component == nil do return

	#partial switch component.type {
	case .TRANSFORM:
		transform := cast(^Transform_Component)component
		if transform != nil {
			entity_manager.transforms[entity] = transform^
		}
	case .RENDERER:
		renderer := cast(^Renderer)component
		if renderer != nil {
			entity_manager.renderers[entity] = renderer^
		}
	case .CAMERA:
		camera := cast(^Camera)component
		if camera != nil {
			entity_manager.cameras[entity] = camera^
		}
	case .LIGHT:
		light := cast(^Light)component
		if light != nil {
			entity_manager.lights[entity] = light^
		}
	case .SCRIPT:
		script := cast(^Script)component
		if script != nil {
			entity_manager.scripts[entity] = script^
		}
	case:
	// Unknown component type
	}
}

// Update a component
update_component :: proc(component: ^Component, delta_time: f32) {
	if interface, ok := component_registry[component.type]; ok {
		interface.update(component, delta_time)
	}
}

// Render a component in the inspector
render_component_inspector :: proc(component: ^Component) {
	if interface, ok := component_registry[component.type]; ok {
		interface.render_inspector(component)
	}
}

// Cleanup a component
cleanup_component :: proc(component: ^Component) {
	if interface, ok := component_registry[component.type]; ok {
		interface.cleanup(component)
		free(component)
	}
}

// Remove a component from an entity
ecs_remove_component :: proc(entity: Entity, type: Component_Type) {
	if !ecs_has_component(entity, type) {
		return
	}

	#partial switch type {
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
	}
}

// Render a generic component header with remove button
render_component_header :: proc(
	title: string,
	entity: Entity,
	component_type: Component_Type,
) -> bool {
	imgui.PushStyleColor(imgui.Col.Button, 0xFF0000FF) // Red color
	imgui.PushStyleColor(imgui.Col.ButtonHovered, 0xFF3333FF) // Lighter red on hover
	imgui.PushStyleColor(imgui.Col.ButtonActive, 0xFF6666FF) // Even lighter red when pressed

	// Create a header with a remove button
	imgui.PushStyleVarImVec2(imgui.StyleVar.FramePadding, imgui.Vec2{2, 2})

	// Render the collapsing header
	is_open := imgui.CollapsingHeader(strings.clone_to_cstring(title))

	// Only show the X button if the header is expanded
	if is_open {
		imgui.Separator()
		imgui.Spacing()
		if imgui.Button("Remove Component", raylib.Vector2{imgui.GetWindowWidth() - 40, 20}) {
			ecs_remove_component(entity, component_type)
			imgui.PopStyleVar()
			imgui.PopStyleColor(3)
			return false
		}
		imgui.Spacing()
	}

	imgui.PopStyleVar()
	imgui.PopStyleColor(3)

	return is_open
}

// Serialize a component
serialize_component :: proc(component: ^Component) -> Component_Data {
	if interface, ok := component_registry[component.type]; ok {
		return interface.serialize(component)
	}
	return nil
}

// Deserialize a component
deserialize_component :: proc(data: Component_Data, entity: Entity) -> ^Component {
	switch v in data {
	case Transform_Component:
		return ecs_add_transform(entity, v.position, v.rotation, v.scale)
	case Renderer:
		return ecs_add_renderer(entity, v.mesh, v.material)
	case Camera:
		return ecs_add_camera(entity, v.fov, v.near, v.far, v.is_main)
	case Light:
		return ecs_add_light(entity, v.light_type, v.color, v.intensity, v.range, v.spot_angle)
	case Script:
		return ecs_add_script(entity, v.script_name)
	}
	return nil
}
