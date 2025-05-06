package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"

// Transform component
Transform_Component :: struct {
	using _base: Component,
	position:    raylib.Vector3,
	rotation:    raylib.Vector3,
	scale:       raylib.Vector3,
}

// Add transform component to an entity
ecs_add_transform :: proc(
	entity: Entity,
	position: raylib.Vector3 = {0, 0, 0},
	rotation: raylib.Vector3 = {0, 0, 0},
	scale: raylib.Vector3 = {1, 1, 1},
) -> ^Transform_Component {
	if !ecs_has_component(entity, .TRANSFORM) {
		transform := Transform_Component {
			_base = Component{type = .TRANSFORM, entity = entity, enabled = true},
			position = position,
			rotation = rotation,
			scale = scale,
		}
		entity_manager.transforms[entity] = transform
		return &entity_manager.transforms[entity]
	}
	return nil
}

// Get transform component from an entity
ecs_get_transform :: proc(entity: Entity) -> ^Transform_Component {
	if ecs_has_component(entity, .TRANSFORM) {
		return &entity_manager.transforms[entity]
	}
	return nil
}

// Get all entities with transform component
ecs_get_transforms :: proc() -> map[Entity]Transform_Component {
	return entity_manager.transforms
}

// Render transform component in inspector
transform_render_inspector :: proc(transform: ^Transform_Component) {
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
