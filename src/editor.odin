#+feature dynamic-literals
package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import raylib "vendor:raylib"

// Editor state
Editor_State :: struct {
	initialized:     bool,
	selected_entity: Entity,
	scene_tree_open: bool,
	inspector_open:  bool,
}

editor: Editor_State

// Initialize the editor
editor_init :: proc() -> bool {
	if editor.initialized {
		return true
	}

	editor = Editor_State {
		initialized     = true,
		scene_tree_open = true,
		inspector_open  = true,
	}

	log_info(.ENGINE, "Editor initialized")
	return true
}

// Update the editor (only in debug mode)
editor_update :: proc() {
	when ODIN_DEBUG {
		if !editor.initialized {
			return
		}
	}
}

// Render the scene tree panel
render_scene_tree :: proc() {
	// Get all entities with transforms
	for entity, transform in entity_manager.transforms {
		// Create selectable item
		name := fmt.tprintf("Entity %d", entity)
		if imgui.Selectable(strings.clone_to_cstring(name), entity == editor.selected_entity) {
			editor.selected_entity = entity
		}
	}
}

// Render the inspector panel
render_inspector :: proc() {
	if editor.selected_entity != 0 {
		// Display entity ID
		imgui.Text("Entity ID: %d", editor.selected_entity)

		// Display transform component if it exists
		if transform := ecs_get_transform(editor.selected_entity); transform != nil {
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
	}
}

// Render the editor UI
editor_render :: proc() {
	if !editor.initialized {
		return
	}

	// Get the main window size
	window_size := imgui.GetIO().DisplaySize
	panel_width := window_size.x * 0.2 // 20% of screen width

	// Render scene tree panel (fixed on left)
	if editor.scene_tree_open {
		imgui.SetNextWindowPos({0, 0})
		imgui.SetNextWindowSize({panel_width, window_size.y})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Scene Tree", &editor.scene_tree_open, window_flags) {
			render_scene_tree()
		}
		imgui.End()
	}

	// Render inspector panel (fixed on right)
	if editor.inspector_open {
		imgui.SetNextWindowPos({window_size.x - panel_width, 0})
		imgui.SetNextWindowSize({panel_width, window_size.y})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Inspector", &editor.inspector_open, window_flags) {
			render_inspector()
		}
		imgui.End()
	}
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
	when ODIN_DEBUG {
		if !editor.initialized {
			return
		}

		log_info(.ENGINE, "Shutting down editor")

		editor.initialized = false
	}
}

// Toggle editor visibility
editor_toggle :: proc() {
	if !editor.initialized {
		return
	}

	editor.scene_tree_open = !editor.scene_tree_open
	editor.inspector_open = !editor.inspector_open
}

// Check if editor is active
editor_is_active :: proc() -> bool {
	when ODIN_DEBUG {
		return editor.initialized
	} else {
		return false
	}
}
