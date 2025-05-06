package component

import "core:fmt"

import fenrir "../"
import imgui "../../vendor/odin-imgui"
import raylib "vendor:raylib"

// Transform component
Transform_Component :: struct {
	using _base: fenrir.Component,
	position:    raylib.Vector3,
	rotation:    raylib.Vector3,
	scale:       raylib.Vector3,
}

// Initialize a transform component
transform_init :: proc(component: ^fenrir.Component, entity: fenrir.Entity) -> bool {
	transform := cast(^Transform_Component)component
	transform.type = .TRANSFORM
	transform.entity = entity
	transform.position = {0, 0, 0}
	transform.rotation = {0, 0, 0}
	transform.scale = {1, 1, 1}
	return true
}

// Update transform component
transform_update :: proc(component: ^fenrir.Component, delta_time: f32) {
	// Add any transform-specific update logic here
}

// Render transform component in inspector
transform_render_inspector :: proc(component: ^fenrir.Component) {
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
transform_cleanup :: proc(component: ^fenrir.Component) {
	// Add any transform-specific cleanup logic here
}

// Register the transform component
transform_register :: proc() {
	fenrir.component_registry[.TRANSFORM] = fenrir.Component_Interface {
		init             = transform_init,
		update           = transform_update,
		render_inspector = transform_render_inspector,
		cleanup          = transform_cleanup,
	}
}
