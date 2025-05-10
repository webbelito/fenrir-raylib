package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"

// Add to the top of the file after imports
Transform_Drag_State :: struct {
	dragging_position: bool,
	dragging_rotation: bool,
	dragging_scale:    bool,
	start_position:    raylib.Vector3,
	start_rotation:    raylib.Vector3,
	start_scale:       raylib.Vector3,
}

drag_state: Transform_Drag_State

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

// Helper function to create transform command when value changes
create_transform_command :: proc(
	transform: ^Transform_Component,
	original_position: raylib.Vector3,
	new_position: raylib.Vector3,
	original_rotation: raylib.Vector3,
	new_rotation: raylib.Vector3,
	original_scale: raylib.Vector3,
	new_scale: raylib.Vector3,
) {
	old_transform := Transform_Component {
		_base    = transform._base,
		position = original_position,
		rotation = original_rotation,
		scale    = original_scale,
	}
	new_transform := Transform_Component {
		_base    = transform._base,
		position = new_position,
		rotation = new_rotation,
		scale    = new_scale,
	}
	cmd := transform_command_create(transform.entity, old_transform, new_transform)
	command_manager_execute(&cmd)
}

// Get the world transform of an entity
get_world_transform :: proc(
	entity: Entity,
) -> (
	position: raylib.Vector3,
	rotation: raylib.Vector3,
	scale: raylib.Vector3,
) {
	if transform := ecs_get_transform(entity); transform != nil {
		position = transform.position
		rotation = transform.rotation
		scale = transform.scale

		// Get the node to find its parent
		if node, ok := scene_manager.current_scene.nodes[entity]; ok {
			// If this entity has a parent, multiply by parent's transform
			if node.parent_id != 0 && node.parent_id != entity {
				parent_pos, parent_rot, parent_scale := get_world_transform(node.parent_id)

				// Calculate world position
				rotation_matrix := raylib.MatrixRotateXYZ(parent_rot)
				position = raylib.Vector3Transform(position, rotation_matrix)
				position += parent_pos

				// Combine rotations
				rotation += parent_rot

				// Combine scales
				scale *= parent_scale
			}
		}
	}
	return
}

// Update the transform component to use world space
transform_render_inspector :: proc(transform: ^Transform_Component) {
	if imgui.CollapsingHeader("Transform") {
		// Get world transform
		world_pos, world_rot, world_scale := get_world_transform(transform.entity)

		// Position section
		imgui.Text("Position (World)")
		imgui.PushItemWidth(60) // Set width for input fields

		new_position := world_pos

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##PosX", &new_position.x, 0.1) {
			// Store initial position when drag starts
			if !drag_state.dragging_position {
				drag_state.dragging_position = true
				drag_state.start_position = transform.position
			}

			// Convert world position to local position
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					parent_pos, parent_rot, _ := get_world_transform(node.parent_id)
					// Convert world position to local position
					local_pos := new_position - parent_pos
					rotation_matrix := raylib.MatrixRotateXYZ(-parent_rot)
					local_pos = raylib.Vector3Transform(local_pos, rotation_matrix)
					transform.position = local_pos
				} else {
					transform.position = new_position
				}
			}
		} else if drag_state.dragging_position && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_position = false
			create_transform_command(
				transform,
				drag_state.start_position,
				transform.position,
				transform.rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##PosY", &new_position.y, 0.1) {
			// Store initial position when drag starts
			if !drag_state.dragging_position {
				drag_state.dragging_position = true
				drag_state.start_position = transform.position
			}

			// Convert world position to local position
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					parent_pos, parent_rot, _ := get_world_transform(node.parent_id)
					// Convert world position to local position
					local_pos := new_position - parent_pos
					rotation_matrix := raylib.MatrixRotateXYZ(-parent_rot)
					local_pos = raylib.Vector3Transform(local_pos, rotation_matrix)
					transform.position = local_pos
				} else {
					transform.position = new_position
				}
			}
		} else if drag_state.dragging_position && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_position = false
			create_transform_command(
				transform,
				drag_state.start_position,
				transform.position,
				transform.rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##PosZ", &new_position.z, 0.1) {
			// Store initial position when drag starts
			if !drag_state.dragging_position {
				drag_state.dragging_position = true
				drag_state.start_position = transform.position
			}

			// Convert world position to local position
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					parent_pos, parent_rot, _ := get_world_transform(node.parent_id)
					// Convert world position to local position
					local_pos := new_position - parent_pos
					rotation_matrix := raylib.MatrixRotateXYZ(-parent_rot)
					local_pos = raylib.Vector3Transform(local_pos, rotation_matrix)
					transform.position = local_pos
				} else {
					transform.position = new_position
				}
			}
		} else if drag_state.dragging_position && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_position = false
			create_transform_command(
				transform,
				drag_state.start_position,
				transform.position,
				transform.rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()
		imgui.PopItemWidth()

		imgui.Separator()

		// Rotation section
		imgui.Text("Rotation (World)")
		imgui.PushItemWidth(60) // Set width for input fields

		new_rotation := world_rot

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##RotX", &new_rotation.x, 0.1) {
			// Store initial rotation when drag starts
			if !drag_state.dragging_rotation {
				drag_state.dragging_rotation = true
				drag_state.start_rotation = transform.rotation
			}

			// Convert world rotation to local rotation
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, parent_rot, _ := get_world_transform(node.parent_id)
					transform.rotation = new_rotation - parent_rot
				} else {
					transform.rotation = new_rotation
				}
			}
		} else if drag_state.dragging_rotation && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_rotation = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				drag_state.start_rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##RotY", &new_rotation.y, 0.1) {
			// Store initial rotation when drag starts
			if !drag_state.dragging_rotation {
				drag_state.dragging_rotation = true
				drag_state.start_rotation = transform.rotation
			}

			// Convert world rotation to local rotation
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, parent_rot, _ := get_world_transform(node.parent_id)
					transform.rotation = new_rotation - parent_rot
				} else {
					transform.rotation = new_rotation
				}
			}
		} else if drag_state.dragging_rotation && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_rotation = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				drag_state.start_rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##RotZ", &new_rotation.z, 0.1) {
			// Store initial rotation when drag starts
			if !drag_state.dragging_rotation {
				drag_state.dragging_rotation = true
				drag_state.start_rotation = transform.rotation
			}

			// Convert world rotation to local rotation
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, parent_rot, _ := get_world_transform(node.parent_id)
					transform.rotation = new_rotation - parent_rot
				} else {
					transform.rotation = new_rotation
				}
			}
		} else if drag_state.dragging_rotation && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_rotation = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				drag_state.start_rotation,
				transform.rotation,
				transform.scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()
		imgui.PopItemWidth()

		imgui.Separator()

		// Scale section
		imgui.Text("Scale (World)")
		imgui.PushItemWidth(60) // Set width for input fields

		new_scale := world_scale

		// X input
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF0000FF) // Red
		imgui.Text("X")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x330000FF) // Red with alpha
		if imgui.DragFloat("##ScaleX", &new_scale.x, 0.1) {
			// Store initial scale when drag starts
			if !drag_state.dragging_scale {
				drag_state.dragging_scale = true
				drag_state.start_scale = transform.scale
			}

			// Convert world scale to local scale
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, _, parent_scale := get_world_transform(node.parent_id)
					transform.scale = new_scale / parent_scale
				} else {
					transform.scale = new_scale
				}
			}
		} else if drag_state.dragging_scale && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_scale = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				transform.rotation,
				transform.rotation,
				drag_state.start_scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Y input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFF00FF00) // Green
		imgui.Text("Y")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x3300FF00) // Green with alpha
		if imgui.DragFloat("##ScaleY", &new_scale.y, 0.1) {
			// Store initial scale when drag starts
			if !drag_state.dragging_scale {
				drag_state.dragging_scale = true
				drag_state.start_scale = transform.scale
			}

			// Convert world scale to local scale
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, _, parent_scale := get_world_transform(node.parent_id)
					transform.scale = new_scale / parent_scale
				} else {
					transform.scale = new_scale
				}
			}
		} else if drag_state.dragging_scale && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_scale = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				transform.rotation,
				transform.rotation,
				drag_state.start_scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()

		// Z input
		imgui.SameLine()
		imgui.AlignTextToFramePadding()
		imgui.PushStyleColor(imgui.Col.Text, 0xFFFF0000) // Blue
		imgui.Text("Z")
		imgui.PopStyleColor()
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.FrameBg, 0x33FF0000) // Blue with alpha
		if imgui.DragFloat("##ScaleZ", &new_scale.z, 0.1) {
			// Store initial scale when drag starts
			if !drag_state.dragging_scale {
				drag_state.dragging_scale = true
				drag_state.start_scale = transform.scale
			}

			// Convert world scale to local scale
			if node, ok := scene_manager.current_scene.nodes[transform.entity]; ok {
				if node.parent_id != 0 && node.parent_id != transform.entity {
					_, _, parent_scale := get_world_transform(node.parent_id)
					transform.scale = new_scale / parent_scale
				} else {
					transform.scale = new_scale
				}
			}
		} else if drag_state.dragging_scale && !imgui.IsMouseDown(.Left) {
			// Create command when drag ends
			drag_state.dragging_scale = false
			create_transform_command(
				transform,
				transform.position,
				transform.position,
				transform.rotation,
				transform.rotation,
				drag_state.start_scale,
				transform.scale,
			)
		}
		imgui.PopStyleColor()
		imgui.PopItemWidth()
	}
}
