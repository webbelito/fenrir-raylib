package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import raylib "vendor:raylib"

// Command to create an entity
Command_Create_Entity :: struct {
	entity:     Entity,
	name:       string,
	parent:     Entity,
	components: map[Component_Type]bool,
}

// Command to destroy an entity
Command_Destroy_Entity :: struct {
	entity:     Entity,
	name:       string,
	parent:     Entity,
	components: map[Component_Type]bool,
}

// Command to rename an entity
Command_Entity_Rename :: struct {
	entity_id: Entity,
	old_name:  string,
	new_name:  string,
}

// Create a new create entity command
create_entity_command_create :: proc(
	name: string = "",
	parent: Entity = 0,
) -> ^Command_Create_Entity {
	command := new(Command_Create_Entity)
	command^ = Command_Create_Entity {
		entity     = ecs_create_entity(),
		name       = name,
		parent     = parent,
		components = make(map[Component_Type]bool),
	}
	return command
}

// Create a new destroy entity command
destroy_entity_command_create :: proc(entity: Entity) -> ^Command_Destroy_Entity {
	command := new(Command_Destroy_Entity)
	command^ = Command_Destroy_Entity {
		entity     = entity,
		name       = ecs_get_entity_name(entity),
		parent     = ecs_get_parent(entity),
		components = make(map[Component_Type]bool),
	}

	// Store which components the entity has
	if ecs_has_component(entity, Transform) {
		command.components[.TRANSFORM] = true
	}
	if ecs_has_component(entity, Renderer) {
		command.components[.RENDERER] = true
	}
	if ecs_has_component(entity, Camera) {
		command.components[.CAMERA] = true
	}
	if ecs_has_component(entity, Light) {
		command.components[.LIGHT] = true
	}
	if ecs_has_component(entity, Script) {
		command.components[.SCRIPT] = true
	}

	return command
}

// Create a new rename entity command
create_entity_rename_command :: proc(entity: Entity, new_name: string) -> ^Command_Entity_Rename {
	command := new(Command_Entity_Rename)
	command^ = Command_Entity_Rename {
		entity_id = entity,
		old_name  = ecs_get_entity_name(entity),
		new_name  = new_name,
	}
	return command
}

// Execute the create entity command
execute_create_entity_command :: proc(command: ^Command_Create_Entity) {
	if command == nil do return

	// Set entity name if provided
	if command.name != "" {
		ecs_set_entity_name(command.entity, command.name)
	}

	// Set parent if provided
	if command.parent != 0 {
		ecs_set_parent(command.entity, command.parent)
	}

	// Add components
	if command.components[.TRANSFORM] {
		transform := Transform {
			position     = {0, 0, 0},
			rotation     = {0, 0, 0},
			scale        = {1, 1, 1},
			local_matrix = raylib.Matrix(1),
			world_matrix = raylib.Matrix(1),
			dirty        = true,
		}
		ecs_add_component(command.entity, Transform, transform)
	}
	if command.components[.RENDERER] {
		renderer := Renderer {
			visible       = true,
			model_type    = .CUBE,
			mesh_path     = "cube",
			material_path = "default",
		}
		ecs_add_component(command.entity, Renderer, renderer)
	}
	if command.components[.CAMERA] {
		camera := Camera {
			fov     = 60,
			near    = 0.1,
			far     = 1000,
			is_main = false,
		}
		ecs_add_component(command.entity, Camera, camera)
	}
	if command.components[.LIGHT] {
		light := Light {
			light_type = .POINT,
			color      = {1, 1, 1},
			intensity  = 1,
			range      = 10,
			spot_angle = 45,
		}
		ecs_add_component(command.entity, Light, light)
	}
	if command.components[.SCRIPT] {
		script := Script {
			script_name = "",
		}
		ecs_add_component(command.entity, Script, script)
	}
}

// Execute the destroy entity command
execute_destroy_entity_command :: proc(command: ^Command_Destroy_Entity) {
	if command == nil do return
	ecs_destroy_entity(command.entity)
}

// Execute the rename entity command
execute_entity_rename_command :: proc(command: ^Command_Entity_Rename) {
	if command == nil do return
	command.old_name = ecs_get_entity_name(command.entity_id)
	ecs_set_entity_name(command.entity_id, command.new_name)
}

// Undo the create entity command
undo_create_entity_command :: proc(command: ^Command_Create_Entity) {
	if command == nil do return
	ecs_destroy_entity(command.entity)
}

// Undo the destroy entity command
undo_destroy_entity_command :: proc(command: ^Command_Destroy_Entity) {
	if command == nil do return

	// Recreate the entity
	entity := ecs_create_entity()

	// Set entity name if provided
	if command.name != "" {
		ecs_set_entity_name(entity, command.name)
	}

	// Set parent if provided
	if command.parent != 0 {
		ecs_set_parent(entity, command.parent)
	}

	// Add components
	if command.components[.TRANSFORM] {
		transform := Transform {
			position     = {0, 0, 0},
			rotation     = {0, 0, 0},
			scale        = {1, 1, 1},
			local_matrix = raylib.Matrix(1),
			world_matrix = raylib.Matrix(1),
			dirty        = true,
		}
		ecs_add_component(entity, Transform, transform)
	}
	if command.components[.RENDERER] {
		renderer := Renderer {
			visible       = true,
			model_type    = .CUBE,
			mesh_path     = "cube",
			material_path = "default",
		}
		ecs_add_component(entity, Renderer, renderer)
	}
	if command.components[.CAMERA] {
		camera := Camera {
			fov     = 60,
			near    = 0.1,
			far     = 1000,
			is_main = false,
		}
		ecs_add_component(entity, Camera, camera)
	}
	if command.components[.LIGHT] {
		light := Light {
			light_type = .POINT,
			color      = {1, 1, 1},
			intensity  = 1,
			range      = 10,
			spot_angle = 45,
		}
		ecs_add_component(entity, Light, light)
	}
	if command.components[.SCRIPT] {
		script := Script {
			script_name = "",
		}
		ecs_add_component(entity, Script, script)
	}
}

// Undo the rename entity command
undo_entity_rename_command :: proc(command: ^Command_Entity_Rename) {
	if command == nil do return
	ecs_set_entity_name(command.entity_id, command.old_name)
}

// Free the create entity command
free_create_entity_command :: proc(command: ^Command_Create_Entity) {
	if command == nil do return
	delete(command.components)
	free(command)
}

// Free the destroy entity command
free_destroy_entity_command :: proc(command: ^Command_Destroy_Entity) {
	if command == nil do return
	delete(command.components)
	free(command)
}

// Free the rename entity command
free_entity_rename_command :: proc(command: ^Command_Entity_Rename) {
	if command == nil do return
	free(command)
}
