# Fenrir Game Engine

A lightweight 3D game engine built with Odin and Raylib, featuring an ECS (Entity Component System) architecture and an ImGui-based editor.

## Project Structure

```
src/
├── main.odin           # Entry point and main loop
├── engine.odin         # Core engine functionality
├── ecs.odin           # Entity Component System implementation
├── component.odin     # Base component system and interfaces
├── scene.odin         # Scene management
├── editor.odin        # ImGui-based editor
├── imgui.odin         # ImGui wrapper
├── time.odin          # Time management
├── asset_manager.odin # Asset loading and management
├── log.odin           # Logging system
└── components/        # Component implementations
    └── transform.odin # Transform component
```

## Core Systems

### Entity Component System (ECS)
- Entity: A unique identifier (u64)
- Component: Data attached to entities
- System: Logic that operates on components

### Scene Management
- Scene loading/saving
- Entity management
- Camera and lighting setup

### Editor
- ImGui-based interface
- Scene hierarchy
- Component inspector
- Real-time editing

## How to Implement a New Component

### 1. Define Component Type
Add your component type to the `Component_Type` enum in `component.odin`:
```odin
Component_Type :: enum {
    TRANSFORM,
    RENDERER,
    CAMERA,
    SCRIPT,
    LIGHT,
    COLLIDER,
    RIGIDBODY,
    AUDIO_SOURCE,
    YOUR_NEW_COMPONENT, // Add your component type here
}
```

### 2. Create Component Structure
Create a new file in the `components` directory (e.g., `components/your_component.odin`):
```odin
package main

import "core:fmt"
import imgui "../vendor/odin-imgui"
import raylib "vendor:raylib"

// Your component structure
Your_Component :: struct {
    using _base: Component,
    // Add your component data here
    some_value: f32,
    another_value: raylib.Vector3,
}

// Initialize your component
your_component_init :: proc(component: ^Component, entity: Entity) -> bool {
    your_component := cast(^Your_Component)component
    your_component.type = .YOUR_NEW_COMPONENT
    your_component.entity = entity
    // Initialize your component data
    your_component.some_value = 0.0
    your_component.another_value = {0, 0, 0}
    return true
}

// Update your component
your_component_update :: proc(component: ^Component, delta_time: f32) {
    // Add update logic here
}

// Render your component in the inspector
your_component_render_inspector :: proc(component: ^Component) {
    your_component := cast(^Your_Component)component
    
    if imgui.CollapsingHeader("Your Component") {
        // Add ImGui controls for your component
        imgui.DragFloat("Some Value", &your_component.some_value, 0.1)
        // Add more controls as needed
    }
}

// Cleanup your component
your_component_cleanup :: proc(component: ^Component) {
    // Add cleanup logic here
}

// Register your component
your_component_register :: proc() {
    component_registry[.YOUR_NEW_COMPONENT] = Component_Interface{
        init = your_component_init,
        update = your_component_update,
        render_inspector = your_component_render_inspector,
        cleanup = your_component_cleanup,
    }
}
```

### 3. Register Your Component
Add your component registration to `component_system_init` in `component.odin`:
```odin
component_system_init :: proc() {
    // Initialize component registry
    component_registry = make(map[Component_Type]Component_Interface)

    // Register existing components
    component_registry[.TRANSFORM] = Component_Interface{...}
    
    // Register your new component
    your_component_register()
}
```

### 4. Add ECS Support
Add your component to the `Entity_Manager` in `ecs.odin`:
```odin
Entity_Manager :: struct {
    next_entity_id: Entity,
    transforms: map[Entity]Transform_Component,
    // Add your component map
    your_components: map[Entity]Your_Component,
}

// Add initialization in ecs_init
ecs_init :: proc() {
    entity_manager.your_components = make(map[Entity]Your_Component)
}

// Add cleanup in ecs_shutdown
ecs_shutdown :: proc() {
    delete(entity_manager.your_components)
}

// Add helper functions
ecs_add_your_component :: proc(entity: Entity, /* parameters */) -> ^Your_Component {
    component := Your_Component{
        _base = Component{type = .YOUR_NEW_COMPONENT, entity = entity, enabled = true},
        // Initialize your component data
    }
    entity_manager.your_components[entity] = component
    return &entity_manager.your_components[entity]
}

ecs_get_your_component :: proc(entity: Entity) -> ^Your_Component {
    if component, ok := &entity_manager.your_components[entity]; ok {
        return component
    }
    return nil
}
```

### 5. Using Your Component
```odin
// Create an entity with your component
entity := ecs_create_entity()
your_component := ecs_add_your_component(entity)

// Get and modify your component
if component := ecs_get_your_component(entity); component != nil {
    component.some_value = 42.0
}
```

## Best Practices
1. Keep components focused on a single responsibility
2. Use the component registry for initialization and cleanup
3. Implement proper inspector UI for editing component values
4. Handle component dependencies appropriately
5. Clean up resources in the cleanup procedure

## Contributing
Feel free to submit issues and enhancement requests! 