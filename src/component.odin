package main

import "core:fmt"

import imgui "../vendor/odin-imgui"
import raylib "vendor:raylib"

// Basic component interface
Component :: struct {
	type:    Component_Type,
	entity:  Entity,
	enabled: bool,
}

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

// Component interface procedures
Component_Interface :: struct {
	init:             proc(_: ^Component, _: Entity) -> bool,
	update:           proc(_: ^Component, _: f32),
	render_inspector: proc(_: ^Component),
	cleanup:          proc(_: ^Component),
}

// Transform component
Transform_Component :: struct {
	using _base: Component,
	position:    raylib.Vector3,
	rotation:    raylib.Vector3,
	scale:       raylib.Vector3,
}

// Initialize a transform component
transform_init :: proc(component: ^Component, entity: Entity) -> bool {
	transform := cast(^Transform_Component)component
	transform.type = .TRANSFORM
	transform.entity = entity
	transform.position = {0, 0, 0}
	transform.rotation = {0, 0, 0}
	transform.scale = {1, 1, 1}
	return true
}

// Update transform component
transform_update :: proc(component: ^Component, delta_time: f32) {
	// Add any transform-specific update logic here
}

// Render transform component in inspector
transform_render_inspector :: proc(component: ^Component) {
	transform := cast(^Transform_Component)component

	if imgui.CollapsingHeader("Transform") {
		// Position section
		imgui.Text("Position")
		imgui.PushItemWidth(60) // Set width for input fields

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##PosX", &transform.position.x, 0.1) {}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##PosY", &transform.position.y, 0.1) {}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##PosZ", &transform.position.z, 0.1) {}
		imgui.PopStyleColor()
		imgui.PopItemWidth()

		imgui.Separator()

		// Rotation section
		imgui.Text("Rotation")
		imgui.PushItemWidth(60) // Set width for input fields

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##RotX", &transform.rotation.x, 0.1) {}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##RotY", &transform.rotation.y, 0.1) {}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##RotZ", &transform.rotation.z, 0.1) {}
		imgui.PopStyleColor()
		imgui.PopItemWidth()

		imgui.Separator()

		// Scale section
		imgui.Text("Scale")
		imgui.PushItemWidth(60) // Set width for input fields

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##ScaleX", &transform.scale.x, 0.1) {}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##ScaleY", &transform.scale.y, 0.1) {}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##ScaleZ", &transform.scale.z, 0.1) {}
		imgui.PopStyleColor()
		imgui.PopItemWidth()
	}
}

// Cleanup transform component
transform_cleanup :: proc(component: ^Component) {
	// Add any transform-specific cleanup logic here
}

// Component registry to store component interfaces
component_registry: map[Component_Type]Component_Interface

// Initialize the component system
component_system_init :: proc() {
	// Initialize component registry
	component_registry = make(map[Component_Type]Component_Interface)

	// Register transform component
	component_registry[.TRANSFORM] = Component_Interface {
		init             = transform_init,
		update           = transform_update,
		render_inspector = transform_render_inspector,
		cleanup          = transform_cleanup,
	}
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
