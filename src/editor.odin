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
	active:              bool,
	initialized:         bool,
	// Panel visibility states
	show_scene_tree:     bool,
	show_inspector:      bool,
	// Selected entity
	selected_entity:     Entity,
	// Docking state
	docking_initialized: bool,
}

editor_state: Editor_State

// Initialize the editor (only in debug mode)
editor_init :: proc() -> bool {
	when ODIN_DEBUG {
		if editor_state.initialized {
			return true
		}

		log_info(.ENGINE, "Initializing editor")

		// Set default state
		editor_state.active = true
		editor_state.initialized = true
		editor_state.show_scene_tree = true
		editor_state.show_inspector = true
		editor_state.selected_entity = 0
		editor_state.docking_initialized = false

		log_info(.ENGINE, "Editor initialized successfully")
		return true
	} else {
		return false
	}
}

// Update the editor (only in debug mode)
editor_update :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized {
			return
		}
	}
}

// Render the scene tree panel
render_scene_tree :: proc() {
	if imgui.Begin("Scene Tree", &editor_state.show_scene_tree) {
		// Get all entities with transforms
		for entity, transform in entity_manager.transforms {
			// Create selectable item
			name := fmt.tprintf("Entity %d", entity)
			if imgui.Selectable(
				strings.clone_to_cstring(name),
				entity == editor_state.selected_entity,
			) {
				editor_state.selected_entity = entity
			}
		}
	}
	imgui.End()
}

// Render the inspector panel
render_inspector :: proc() {
	if imgui.Begin("Inspector", &editor_state.show_inspector) {
		if editor_state.selected_entity != 0 {
			// Display entity ID
			imgui.Text("Entity ID: %d", editor_state.selected_entity)

			// Display transform component if it exists
			if transform := ecs_get_transform(editor_state.selected_entity); transform != nil {
				if imgui.CollapsingHeader("Transform") {
					// Position
					pos := transform.position
					if imgui.DragFloat3("Position", &pos, 0.1) {
						transform.position = pos
					}

					// Rotation
					rot := transform.rotation
					if imgui.DragFloat3("Rotation", &rot, 0.1) {
						transform.rotation = rot
					}

					// Scale
					scale := transform.scale
					if imgui.DragFloat3("Scale", &scale, 0.1) {
						transform.scale = scale
					}
				}
			}
		} else {
			imgui.Text("No entity selected")
		}
	}
	imgui.End()
}

// Render the viewport panel
render_viewport :: proc() {
	if imgui.Begin("Viewport") {
		// TODO: Render the actual 3D viewport here
		// This will require setting up a render texture and proper viewport handling
	}
	imgui.End()
}

// Render the editor UI
editor_render :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized || !editor_state.active {
			return
		}

		// Set up the docking layout on first frame
		if !editor_state.docking_initialized {
			dock_space_id := imgui.GetID("DockSpace")
			imgui.DockBuilderRemoveNode(dock_space_id)

			// Create the main dock node
			dock_main_id := imgui.DockBuilderAddNode(dock_space_id, {.KeepAliveOnly})
			if dock_main_id != 0 {
				// Set the main dock node as the central node
				imgui.DockBuilderSetNodeSize(dock_main_id, imgui.GetIO().DisplaySize)

				// Setup docking splits
				dock_id_left := imgui.DockBuilderSplitNode(
					dock_main_id,
					.Left,
					0.2,
					nil,
					&dock_main_id,
				)
				dock_id_right := imgui.DockBuilderSplitNode(
					dock_main_id,
					.Right,
					0.25,
					nil,
					&dock_main_id,
				)

				// Dock windows
				imgui.DockBuilderDockWindow("Scene Tree", dock_id_left)
				imgui.DockBuilderDockWindow("Viewport", dock_main_id)
				imgui.DockBuilderDockWindow("Inspector", dock_id_right)

				// Finish the docking setup
				imgui.DockBuilderFinish(dock_space_id)
				editor_state.docking_initialized = true
			}
		}

		// Set up the docking layout
		dock_space_id := imgui.GetID("DockSpace")
		window_flags := imgui.WindowFlags{.NoDocking}
		window_flags += {.NoTitleBar, .NoCollapse, .NoResize, .NoMove}
		window_flags += {.NoBringToFrontOnFocus, .NoNavFocus}

		main_viewport := imgui.GetMainViewport()
		imgui.SetNextWindowPos(main_viewport.WorkPos)
		imgui.SetNextWindowSize(main_viewport.WorkSize)

		style_var_rounding := imgui.StyleVar.WindowRounding
		style_var_border := imgui.StyleVar.WindowBorderSize
		style_var_padding := imgui.StyleVar.WindowPadding

		imgui.PushStyleVar(style_var_rounding, 0.0)
		imgui.PushStyleVar(style_var_border, 0.0)
		imgui.PushStyleVarImVec2(style_var_padding, imgui.Vec2{0.0, 0.0})

		if imgui.Begin("DockSpace", nil, window_flags) {
			imgui.PopStyleVar(3)

			// Create the dock space
			dock_flags := imgui.DockNodeFlags{.NoDockingOverCentralNode}
			imgui.DockSpace(dock_space_id, imgui.Vec2{0.0, 0.0}, dock_flags)

			// Render our panels
			render_scene_tree()
			render_viewport()
			render_inspector()
		}
		imgui.End()

		// Show ImGui demo window
		demo_open := true
		imgui.ShowDemoWindow(&demo_open)
	}
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized {
			return
		}

		log_info(.ENGINE, "Shutting down editor")

		// Shutdown ImGui
		imgui_shutdown()

		editor_state.initialized = false
		editor_state.active = false
	}
}

// Toggle editor visibility
editor_toggle :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized {
			return
		}

		editor_state.active = !editor_state.active
		log_info(.ENGINE, "Editor active: %v", editor_state.active)
	}
}

// Check if editor is active
editor_is_active :: proc() -> bool {
	when ODIN_DEBUG {
		return editor_state.initialized && editor_state.active
	} else {
		return false
	}
}
