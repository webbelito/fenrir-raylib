package main

import "core:log"
import "core:mem"
import "core:strings"

// Entity command data structures
Command_Entity_Add :: struct {
	entity_id: Entity,
	name:      string,
}

Command_Entity_Delete :: struct {
	entity_id:  Entity,
	name:       string,
	components: map[Component_Type]rawptr,
}

Command_Entity_Rename :: struct {
	entity_id: Entity,
	old_name:  string,
	new_name:  string,
}

// Create entity command
Command_Create_Entity :: struct {
	using command: Command,
	entity_id:     Entity,
	name:          string,
	components:    map[Component_Type]^Component,
}

// Entity command vtable implementations
entity_add_vtable := Command_VTable {
	execute = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Add)cmd.data
		if data == nil do return

		// Create the entity
		data.entity_id = scene_manager_create_entity(data.name)
	},
	undo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Add)cmd.data
		if data == nil do return

		// Delete the entity
		scene_manager_delete_entity(data.entity_id)
	},
	redo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Add)cmd.data
		if data == nil do return

		// Recreate the entity
		data.entity_id = scene_manager_create_entity(data.name)
	},
	destroy = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Add)cmd.data
		if data == nil do return

		delete(data.name)
		free(data)
	},
	copy = proc(cmd: ^Command) -> Command {
		data := cast(^Command_Entity_Add)cmd.data
		if data == nil do return Command{}

		new_data := new(Command_Entity_Add)
		new_data^ = data^
		new_data.name = strings.clone(data.name)

		return Command{vtable = cmd.vtable, data = new_data}
	},
}

entity_delete_vtable := Command_VTable {
	execute = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Delete)cmd.data
		if data == nil do return

		// Store entity data before deletion
		data.name = ecs_get_entity_name(data.entity_id)
		data.components = make(map[Component_Type]rawptr)

		// Store component data
		if transform := ecs_get_component(data.entity_id, .TRANSFORM); transform != nil {
			ptr, err := mem.alloc(size_of(Transform_Component))
			if err == nil {
				mem.copy(ptr, cast(^Transform_Component)transform, size_of(Transform_Component))
				data.components[.TRANSFORM] = ptr
			}
		}
		if renderer := ecs_get_component(data.entity_id, .RENDERER); renderer != nil {
			ptr, err := mem.alloc(size_of(Renderer))
			if err == nil {
				mem.copy(ptr, cast(^Renderer)renderer, size_of(Renderer))
				data.components[.RENDERER] = ptr
			}
		}
		if light := ecs_get_component(data.entity_id, .LIGHT); light != nil {
			ptr, err := mem.alloc(size_of(Light))
			if err == nil {
				mem.copy(ptr, cast(^Light)light, size_of(Light))
				data.components[.LIGHT] = ptr
			}
		}
		if camera := ecs_get_component(data.entity_id, .CAMERA); camera != nil {
			ptr, err := mem.alloc(size_of(Camera))
			if err == nil {
				mem.copy(ptr, cast(^Camera)camera, size_of(Camera))
				data.components[.CAMERA] = ptr
			}
		}

		// Delete the entity
		scene_manager_delete_entity(data.entity_id)
	},
	undo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Delete)cmd.data
		if data == nil do return

		// Recreate the entity
		data.entity_id = scene_manager_create_entity(data.name)

		// Restore components
		if transform := cast(^Transform_Component)data.components[.TRANSFORM]; transform != nil {
			new_transform := ecs_add_transform(data.entity_id)
			if new_transform != nil {
				new_transform^ = transform^
			}
		}
		if renderer := cast(^Renderer)data.components[.RENDERER]; renderer != nil {
			new_renderer := ecs_add_renderer(data.entity_id)
			if new_renderer != nil {
				new_renderer^ = renderer^
				new_renderer.mesh_path = renderer.mesh_path
				new_renderer.material_path = renderer.material_path
			}
		}
		if light := cast(^Light)data.components[.LIGHT]; light != nil {
			new_light := ecs_add_light(
				data.entity_id,
				light.light_type,
				light.color,
				light.intensity,
				light.range,
				light.spot_angle,
			)
			if new_light != nil {
				new_light^ = light^
			}
		}
		if camera := cast(^Camera)data.components[.CAMERA]; camera != nil {
			new_camera := ecs_add_camera(
				data.entity_id,
				camera.fov,
				camera.near,
				camera.far,
				camera.is_main,
			)
			if new_camera != nil {
				new_camera^ = camera^
			}
		}
	},
	redo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Delete)cmd.data
		if data == nil do return

		// Delete the entity
		scene_manager_delete_entity(data.entity_id)
	},
	destroy = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Delete)cmd.data
		if data == nil do return

		delete(data.name)
		for _, component in data.components {
			free(component)
		}
		delete(data.components)
		free(data)
	},
	copy = proc(cmd: ^Command) -> Command {
		data := cast(^Command_Entity_Delete)cmd.data
		if data == nil do return Command{}

		new_data := new(Command_Entity_Delete)
		new_data^ = data^
		new_data.name = strings.clone(data.name)
		new_data.components = make(map[Component_Type]rawptr)

		// Deep copy components
		for type, component in data.components {
			size: int
			if type == .TRANSFORM {
				size = size_of(Transform_Component)
			} else if type == .RENDERER {
				size = size_of(Renderer)
			} else if type == .LIGHT {
				size = size_of(Light)
			} else if type == .CAMERA {
				size = size_of(Camera)
			} else {
				size = 0
			}
			if size > 0 {
				ptr, err := mem.alloc(size)
				if err == nil {
					mem.copy(ptr, component, size)
					new_data.components[type] = ptr
				}
			}
		}

		return Command{vtable = cmd.vtable, data = new_data}
	},
}

entity_rename_vtable := Command_VTable {
	execute = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Rename)cmd.data
		if data == nil do return

		// Store old name
		data.old_name = ecs_get_entity_name(data.entity_id)

		// Set new name
		ecs_set_entity_name(data.entity_id, data.new_name)
	},
	undo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Rename)cmd.data
		if data == nil do return

		// Restore old name
		ecs_set_entity_name(data.entity_id, data.old_name)
	},
	redo = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Rename)cmd.data
		if data == nil do return

		// Set new name
		ecs_set_entity_name(data.entity_id, data.new_name)
	},
	destroy = proc(cmd: ^Command) {
		data := cast(^Command_Entity_Rename)cmd.data
		if data == nil do return

		delete(data.old_name)
		delete(data.new_name)
		free(data)
	},
	copy = proc(cmd: ^Command) -> Command {
		data := cast(^Command_Entity_Rename)cmd.data
		if data == nil do return Command{}

		new_data := new(Command_Entity_Rename)
		new_data^ = data^
		new_data.old_name = strings.clone(data.old_name)
		new_data.new_name = strings.clone(data.new_name)

		return Command{vtable = cmd.vtable, data = new_data}
	},
}

// Command creation functions
command_create_entity_add :: proc(name: string, parent: Entity = 0) -> Command {
	data := new(Command_Entity_Add)
	data.name = strings.clone(name)
	data.entity_id = 0

	return Command{vtable = &entity_add_vtable, data = data}
}

command_create_entity_delete :: proc(entity_id: Entity) -> Command {
	data := new(Command_Entity_Delete)
	data.entity_id = entity_id
	data.name = ""
	data.components = make(map[Component_Type]rawptr)

	return Command{vtable = &entity_delete_vtable, data = data}
}

command_create_entity_rename :: proc(entity_id: Entity, new_name: string) -> Command {
	data := new(Command_Entity_Rename)
	data.entity_id = entity_id
	data.old_name = ""
	data.new_name = strings.clone(new_name)

	return Command{vtable = &entity_rename_vtable, data = data}
}

// Create entity command vtable
create_entity_vtable: Command_VTable

init_create_entity_vtable :: proc() {
	create_entity_vtable = Command_VTable {
		execute = proc(cmd: ^Command) {
			data := cast(^Command_Create_Entity)cmd.data
			if data == nil do return

			// Create the entity
			data.entity_id = ecs_create_entity(data.name)
			if data.entity_id == 0 do return

			// Add components
			if transform, ok := entity_manager.transforms[data.entity_id]; ok {
				component := new(Transform_Component)
				component^ = transform
				data.components[.TRANSFORM] = cast(^Component)component
			}
			if renderer, ok := entity_manager.renderers[data.entity_id]; ok {
				component := new(Renderer)
				component^ = renderer
				data.components[.RENDERER] = cast(^Component)component
			}
			if light, ok := entity_manager.lights[data.entity_id]; ok {
				component := new(Light)
				component^ = light
				data.components[.LIGHT] = cast(^Component)component
			}
			if camera, ok := entity_manager.cameras[data.entity_id]; ok {
				component := new(Camera)
				component^ = camera
				data.components[.CAMERA] = cast(^Component)component
			}
		},
		undo = proc(cmd: ^Command) {
			data := cast(^Command_Create_Entity)cmd.data
			if data == nil do return

			// Destroy the entity
			ecs_destroy_entity(data.entity_id)
		},
		redo = proc(cmd: ^Command) {
			data := cast(^Command_Create_Entity)cmd.data
			if data == nil do return

			// Create the entity
			data.entity_id = ecs_create_entity(data.name)
			if data.entity_id == 0 do return

			// Add components
			if transform, ok := entity_manager.transforms[data.entity_id]; ok {
				component := new(Transform_Component)
				component^ = transform
				data.components[.TRANSFORM] = cast(^Component)component
			}
			if renderer, ok := entity_manager.renderers[data.entity_id]; ok {
				component := new(Renderer)
				component^ = renderer
				data.components[.RENDERER] = cast(^Component)component
			}
			if light, ok := entity_manager.lights[data.entity_id]; ok {
				component := new(Light)
				component^ = light
				data.components[.LIGHT] = cast(^Component)component
			}
			if camera, ok := entity_manager.cameras[data.entity_id]; ok {
				component := new(Camera)
				component^ = camera
				data.components[.CAMERA] = cast(^Component)component
			}
		},
		destroy = proc(cmd: ^Command) {
			data := cast(^Command_Create_Entity)cmd.data
			if data == nil do return

			// Clean up component data
			for _, component in data.components {
				if component != nil {
					free(component)
				}
			}
			clear(&data.components)
			free(data)
		},
		copy = proc(cmd: ^Command) -> Command {
			data := cast(^Command_Create_Entity)cmd.data
			if data == nil do return Command{}

			new_data := new(Command_Create_Entity)
			new_data^ = data^

			// Deep copy components
			new_data.components = make(map[Component_Type]^Component)
			for type, component in data.components {
				if component != nil {
					new_data.components[type] = component
				}
			}

			return Command{vtable = &create_entity_vtable, data = new_data}
		},
	}
}

// Create entity command
create_entity_command :: proc(name: string) -> ^Command {
	data := new(Command_Create_Entity)
	data^ = Command_Create_Entity {
		entity_id  = 0,
		name       = name,
		components = make(map[Component_Type]^Component),
	}

	cmd := new(Command)
	cmd^ = Command {
		vtable = &create_entity_vtable,
		data   = data,
	}
	return cmd
}
