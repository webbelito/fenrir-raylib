package main

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:time"

// System function types
System_Init_Proc :: proc(registry: ^Component_Registry)
System_Update_Proc :: proc(registry: ^Component_Registry, dt: f32)
System_Shutdown_Proc :: proc(registry: ^Component_Registry)

// System definition
System :: struct {
	name:         string,
	init:         System_Init_Proc,
	update:       System_Update_Proc,
	fixed_update: System_Update_Proc,
	shutdown:     System_Shutdown_Proc,
	enabled:      bool,
	priority:     int, // Lower numbers run first
}

// Systems manager
System_Manager :: struct {
	systems:     [dynamic]System,
	initialized: bool,
}

// Initialize the system manager
system_manager_init :: proc() -> System_Manager {
	return System_Manager{systems = make([dynamic]System), initialized = false}
}

// Destroy the system manager
system_manager_destroy :: proc(manager: ^System_Manager) {
	delete(manager.systems)
}

// Register a system
system_manager_register :: proc(manager: ^System_Manager, system: System) {
	// Find the right position based on priority
	insert_idx := 0
	for i := 0; i < len(manager.systems); i += 1 {
		if manager.systems[i].priority > system.priority {
			break
		}
		insert_idx = i + 1
	}

	// Insert the system at the right position
	if insert_idx == len(manager.systems) {
		append(&manager.systems, system)
	} else {
		// Make space and insert
		append(&manager.systems, System{})
		for i := len(manager.systems) - 1; i > insert_idx; i -= 1 {
			manager.systems[i] = manager.systems[i - 1]
		}
		manager.systems[insert_idx] = system
	}
}

// Initialize all systems
system_manager_initialize_all :: proc(manager: ^System_Manager, registry: ^Component_Registry) {
	if manager.initialized {
		return
	}

	log_info(.ENGINE, "Initializing %d systems", len(manager.systems))

	for _, i in manager.systems {
		system := &manager.systems[i]
		if system.init != nil {
			log_debug(.ENGINE, "Initializing system: %s", system.name)
			system.init(registry)
		}
	}

	manager.initialized = true
	log_info(.ENGINE, "All systems initialized")
}

// Update all systems
system_manager_update_all :: proc(
	manager: ^System_Manager,
	registry: ^Component_Registry,
	dt: f32,
) {
	if !manager.initialized {
		return
	}

	for _, i in manager.systems {
		system := &manager.systems[i]
		if system.enabled && system.update != nil {
			system.update(registry, dt)
		}
	}
}

// Run fixed update on all systems
system_manager_fixed_update_all :: proc(
	manager: ^System_Manager,
	registry: ^Component_Registry,
	fixed_dt: f32,
) {
	if !manager.initialized {
		return
	}

	for _, i in manager.systems {
		system := &manager.systems[i]
		if system.enabled && system.fixed_update != nil {
			system.fixed_update(registry, fixed_dt)
		}
	}
}

// Shutdown all systems
system_manager_shutdown_all :: proc(manager: ^System_Manager, registry: ^Component_Registry) {
	if !manager.initialized {
		return
	}

	log_info(.ENGINE, "Shutting down all systems")

	// Shutdown in reverse order of initialization
	for i := len(manager.systems) - 1; i >= 0; i -= 1 {
		system := &manager.systems[i]
		if system.shutdown != nil {
			log_debug(.ENGINE, "Shutting down system: %s", system.name)
			system.shutdown(registry)
		}
	}

	manager.initialized = false
	log_info(.ENGINE, "All systems shut down")
}

// Enable a system by name
system_manager_enable :: proc(manager: ^System_Manager, name: string) -> bool {
	for _, i in manager.systems {
		if manager.systems[i].name == name {
			manager.systems[i].enabled = true
			return true
		}
	}
	return false
}

// Disable a system by name
system_manager_disable :: proc(manager: ^System_Manager, name: string) -> bool {
	for _, i in manager.systems {
		if manager.systems[i].name == name {
			manager.systems[i].enabled = false
			return true
		}
	}
	return false
}

// Get a system by name
system_manager_get :: proc(manager: ^System_Manager, name: string) -> ^System {
	for _, i in manager.systems {
		if manager.systems[i].name == name {
			return &manager.systems[i]
		}
	}
	return nil
}
