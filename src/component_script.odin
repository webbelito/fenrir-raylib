package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Script component
Script :: struct {
	using _base: Component,
	script_name: string,
	parameters:  map[string]f32,
	// In a real implementation, this would have references to script instances
}

// Add script component to an entity
ecs_add_script :: proc(entity: Entity, script_name: string) -> ^Script {
	if !ecs_has_component(entity, .SCRIPT) {
		script := Script {
			_base = Component{type = .SCRIPT, entity = entity, enabled = true},
			script_name = script_name,
		}
		entity_manager.scripts[entity] = script
		return &entity_manager.scripts[entity]
	}
	return nil
}

// Get script component from an entity
ecs_get_script :: proc(entity: Entity) -> ^Script {
	if ecs_has_component(entity, .SCRIPT) {
		return &entity_manager.scripts[entity]
	}
	return nil
}

// Get all entities with script component
ecs_get_scripts :: proc() -> map[Entity]Script {
	return entity_manager.scripts
}

// Render script component in inspector
script_render_inspector :: proc(script: ^Script) {
	if imgui.CollapsingHeader("Script") {
		imgui.PushItemWidth(-1)

		// Script selection
		if imgui.BeginCombo("Script", strings.clone_to_cstring(script.script_name)) {
			if imgui.Selectable("Empty", script.script_name == "") {
				script.script_name = ""
			}
			if imgui.Selectable("Player Controller", script.script_name == "player_controller") {
				script.script_name = "player_controller"
			}
			if imgui.Selectable("Camera Controller", script.script_name == "camera_controller") {
				script.script_name = "camera_controller"
			}
			imgui.EndCombo()
		}

		// Script parameters
		if len(script.parameters) > 0 {
			imgui.Separator()
			imgui.Text("Parameters")

			for name, value in script.parameters {
				if imgui.DragFloat(strings.clone_to_cstring(name), &script.parameters[name], 0.1) {
					// Parameter changed
				}
			}
		}

		imgui.PopItemWidth()
	}
}
