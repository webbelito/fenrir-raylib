package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"

// Render the editor menu bar
editor_menu_render :: proc() {
	if imgui.BeginMainMenuBar() {
		// File menu
		if imgui.BeginMenu("File") {
			if imgui.MenuItem("New Scene") {
				scene_manager_new("Untitled")
			}
			if imgui.MenuItem("Open Scene") {
				if !check_unsaved_changes("open") {
					scan_directory(editor.current_dir)
					editor.show_open_dialog = true
				}
			}
			if imgui.MenuItem("Save Scene") {
				if editor.scene_path == "" {
					editor.show_save_dialog = true
					// Initialize the name buffer with zeros
					for i in 0 ..< len(editor.save_dialog_name) {
						editor.save_dialog_name[i] = 0
					}
					// Copy current scene name if it exists
					if scene_manager.current_scene.name != "" {
						copy(editor.save_dialog_name[:], scene_manager.current_scene.name)
					}
				} else {
					scene_manager_save(editor.scene_path)
				}
			}
			if imgui.MenuItem("Save Scene As...") {
				editor.show_save_dialog = true
				// Initialize the name buffer with zeros
				for i in 0 ..< len(editor.save_dialog_name) {
					editor.save_dialog_name[i] = 0
				}
				// Copy current scene name if it exists
				if scene_manager.current_scene.name != "" {
					copy(editor.save_dialog_name[:], scene_manager.current_scene.name)
				}
			}
			imgui.Separator()
			if imgui.MenuItem("Exit", "Alt+F4") {
				if !check_unsaved_changes("exit") {
					// TODO: Handle exit
				}
			}
			imgui.EndMenu()
		}

		// Edit menu
		if imgui.BeginMenu("Edit") {
			if imgui.MenuItem("Undo", "Ctrl+Z", false, command_manager_can_undo()) {
				command_manager_undo()
			}
			if imgui.MenuItem("Redo", "Ctrl+Y", false, command_manager_can_redo()) {
				command_manager_redo()
			}
			imgui.Separator()
			if imgui.MenuItem("Delete Selected", "Delete", false, editor.selected_entity != 0) {
				if editor.selected_entity != 0 {
					scene_manager_delete_node(editor.selected_entity)
				}
			}
			imgui.EndMenu()
		}

		// Window menu
		if imgui.BeginMenu("Window") {
			if imgui.MenuItem("Scene Tree", nil, editor.scene_tree_open) {
				editor.scene_tree_open = !editor.scene_tree_open
			}
			if imgui.MenuItem("Inspector", nil, editor.inspector_open) {
				editor.inspector_open = !editor.inspector_open
			}
			imgui.EndMenu()
		}

		imgui.EndMainMenuBar()
	}
}
