package main

import imgui "../vendor/odin-imgui"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

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

// Component inspector functions
transform_render_inspector :: proc(transform: ^Transform_Component) {
	if transform == nil do return
	if imgui.CollapsingHeader("Transform") {
		pos := [3]f32{transform.position.x, transform.position.y, transform.position.z}
		rot := [3]f32{transform.rotation.x, transform.rotation.y, transform.rotation.z}
		scale := [3]f32{transform.scale.x, transform.scale.y, transform.scale.z}
		if imgui.DragFloat3("Position", &pos, 0.1) {
			transform.position = {pos[0], pos[1], pos[2]}
			transform.dirty = true
		}
		if imgui.DragFloat3("Rotation", &rot, 1.0) {
			transform.rotation = {rot[0], rot[1], rot[2]}
			transform.dirty = true
		}
		if imgui.DragFloat3("Scale", &scale, 0.1) {
			transform.scale = {scale[0], scale[1], scale[2]}
			transform.dirty = true
		}
	}
}

renderer_render_inspector :: proc(renderer: ^Renderer) {
	if renderer == nil do return
	if imgui.CollapsingHeader("Renderer") {
		imgui.Checkbox("Visible", &renderer.visible)
		if imgui.BeginCombo("Model Type", renderer.model_type == .CUBE ? "Cube" : "Custom") {
			if imgui.Selectable("Cube", renderer.model_type == .CUBE) {
				renderer.model_type = .CUBE
				renderer.mesh_path = "cube"
				renderer.material_path = "default"
			}
			if imgui.Selectable("Custom", renderer.model_type == .CUSTOM) {
				renderer.model_type = .CUSTOM
			}
			imgui.EndCombo()
		}
		if renderer.model_type == .CUSTOM {
			mesh_buf: [256]u8
			material_buf: [256]u8
			copy(mesh_buf[:], renderer.mesh_path)
			copy(material_buf[:], renderer.material_path)
			if imgui.InputText("Mesh Path", cstring(raw_data(mesh_buf[:])), len(mesh_buf)) {
				renderer.mesh_path = string(mesh_buf[:])
			}
			if imgui.InputText(
				"Material Path",
				cstring(raw_data(material_buf[:])),
				len(material_buf),
			) {
				renderer.material_path = string(material_buf[:])
			}
		}
	}
}

camera_render_inspector :: proc(camera: ^Camera) {
	if camera == nil do return
	if imgui.CollapsingHeader("Camera") {
		imgui.DragFloat("FOV", &camera.fov, 1.0, 1.0, 179.0)
		imgui.DragFloat("Near", &camera.near, 0.1, 0.1, 100.0)
		imgui.DragFloat("Far", &camera.far, 1.0, 1.0, 10000.0)
		imgui.Checkbox("Is Main Camera", &camera.is_main)
	}
}

light_render_inspector :: proc(light: ^Light) {
	if light == nil do return
	if imgui.CollapsingHeader("Light") {
		if imgui.BeginCombo(
			"Light Type",
			light.light_type == .DIRECTIONAL ? "Directional" : "Point",
		) {
			if imgui.Selectable("Directional", light.light_type == .DIRECTIONAL) {
				light.light_type = .DIRECTIONAL
			}
			if imgui.Selectable("Point", light.light_type == .POINT) {
				light.light_type = .POINT
			}
			imgui.EndCombo()
		}
		color := [3]f32{light.color.x, light.color.y, light.color.z}
		if imgui.ColorEdit3("Color", &color) {
			light.color = {color[0], color[1], color[2]}
		}
		imgui.DragFloat("Intensity", &light.intensity, 0.1, 0.0, 10.0)
		if light.light_type == .POINT {
			imgui.DragFloat("Range", &light.range, 0.1, 0.0, 100.0)
		}
	}
}

script_render_inspector :: proc(script: ^Script) {
	if script == nil do return
	if imgui.CollapsingHeader("Script") {
		script_buf: [256]u8
		copy(script_buf[:], script.script_name)
		if imgui.InputText("Script Name", cstring(raw_data(script_buf[:])), len(script_buf)) {
			script.script_name = string(script_buf[:])
		}
	}
}

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
			transform.local_matrix = raylib.Matrix(1)
			transform.world_matrix = raylib.Matrix(1)
			transform.dirty = true
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			transform := cast(^Transform_Component)component
			if transform == nil do return
			// Update transform matrices
			transform.local_matrix =
				raylib.MatrixScale(transform.scale.x, transform.scale.y, transform.scale.z) *
				raylib.MatrixRotateXYZ(transform.rotation * raylib.DEG2RAD) *
				raylib.MatrixTranslate(
					transform.position.x,
					transform.position.y,
					transform.position.z,
				)
			transform.world_matrix = transform.local_matrix
			transform.dirty = false
		},
		render_inspector = proc(component: ^Component) {
			transform := cast(^Transform_Component)component
			transform_render_inspector(transform)
		},
		cleanup = proc(component: ^Component) {
			// No cleanup needed for transform
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
			renderer.model_type = .CUBE
			renderer.mesh_path = ""
			renderer.material_path = ""
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Renderer-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			renderer := cast(^Renderer)component
			renderer_render_inspector(renderer)
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
			return ecs_add_renderer(entity)
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
			camera_render_inspector(camera)
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
			light.light_type = .DIRECTIONAL
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
			light_render_inspector(light)
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
			return ecs_add_light(entity, light.light_type)
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
			script.script_name = ""
			return true
		},
		update = proc(component: ^Component, delta_time: f32) {
			// Script-specific update logic
		},
		render_inspector = proc(component: ^Component) {
			script := cast(^Script)component
			script_render_inspector(script)
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
		component := new(Component)
		if interface.init(component, entity) {
			return component
		}
		free(component)
	}
	return nil
}

// Add a component to an entity
ecs_add_component :: proc(entity: Entity, component: ^Component) -> bool {
	if entity == 0 || component == nil do return false

	#partial switch component.type {
	case .TRANSFORM:
		transform := cast(^Transform_Component)component
		entity_manager.transforms[entity] = transform^
	case .RENDERER:
		renderer := cast(^Renderer)component
		entity_manager.renderers[entity] = renderer^
	case .CAMERA:
		camera := cast(^Camera)component
		entity_manager.cameras[entity] = camera^
	case .LIGHT:
		light := cast(^Light)component
		entity_manager.lights[entity] = light^
	case .SCRIPT:
		script := cast(^Script)component
		entity_manager.scripts[entity] = script^
	case:
		return false
	}

	return true
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
ecs_remove_component :: proc(entity: Entity, type: Component_Type) -> bool {
	if entity == 0 do return false

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
	case:
		return false
	}

	return true
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
		return ecs_add_renderer(entity)
	case Camera:
		return ecs_add_camera(entity, v.fov, v.near, v.far, v.is_main)
	case Light:
		return ecs_add_light(entity, v.light_type)
	case Script:
		return ecs_add_script(entity, v.script_name)
	}
	return nil
}

// Update all components of a specific type
ecs_update_components :: proc(type: Component_Type, delta_time: f32) {
	if interface, ok := component_registry[type]; ok {
		for entity in ecs_get_entities_with_component(type) {
			if component := ecs_get_component(entity, type); component != nil {
				interface.update(component, delta_time)
			}
		}
	}
}

// Render inspector for all components of a specific type
ecs_render_component_inspectors :: proc(type: Component_Type) {
	if interface, ok := component_registry[type]; ok {
		for entity in ecs_get_entities_with_component(type) {
			if component := ecs_get_component(entity, type); component != nil {
				interface.render_inspector(component)
			}
		}
	}
}

// Cleanup all components of a specific type
ecs_cleanup_components :: proc(type: Component_Type) {
	if interface, ok := component_registry[type]; ok {
		for entity in ecs_get_entities_with_component(type) {
			if component := ecs_get_component(entity, type); component != nil {
				interface.cleanup(component)
			}
		}
	}
}

// Serialize all components of a specific type
ecs_serialize_components :: proc(type: Component_Type) -> []Component_Data {
	data: [dynamic]Component_Data
	if interface, ok := component_registry[type]; ok {
		for entity in ecs_get_entities_with_component(type) {
			if component := ecs_get_component(entity, type); component != nil {
				append(&data, interface.serialize(component))
			}
		}
	}
	return data[:]
}

// Deserialize components of a specific type
ecs_deserialize_components :: proc(type: Component_Type, data: []Component_Data) {
	if interface, ok := component_registry[type]; ok {
		for d in data {
			if component := interface.deserialize(d, 0); component != nil {
				// TODO: Handle entity creation/assignment
			}
		}
	}
}
