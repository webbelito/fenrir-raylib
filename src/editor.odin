package main

import "core:strings"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"

// Constants for editor layout
PANEL_WIDTH :: 250
SCENE_TREE_HEIGHT :: 0.5 // percentage of screen height

// Editor theme colors
PANEL_COLOR :: raylib.DARKGRAY
PANEL_BORDER_COLOR :: raylib.BLACK
TITLE_COLOR :: raylib.WHITE
SELECTED_COLOR :: raylib.BLUE
TEXT_COLOR :: raylib.WHITE
HIGHLIGHTED_TEXT_COLOR :: raylib.YELLOW

// Editor state
Editor_State :: struct {
    active: bool,
    initialized: bool,
    
    // Panel rectangles
    scene_tree_rect: raylib.Rectangle,
    inspector_rect: raylib.Rectangle,
    viewport_rect: raylib.Rectangle,
    
    // Selected node info
    selected_node_index: int,
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
        editor_state.selected_node_index = -1
        
        // Calculate initial panel layouts
        editor_update_layout()
        
        return true
    } else {
        return false
    }
}

// Update the editor (only in debug mode)
editor_update :: proc() -> bool {
    when ODIN_DEBUG {
        if !editor_state.initialized || !editor_state.active {
            return false
        }
        
        // Update panel layouts if window resized
        editor_update_layout()
        
        // Handle input (e.g., selecting nodes)
        if raylib.IsMouseButtonPressed(.LEFT) {
            mouse_pos := raylib.GetMousePosition()
            
            // Check if clicked in scene tree area
            if raylib.CheckCollisionPointRec(mouse_pos, editor_state.scene_tree_rect) {
                // Simple demonstration of node selection
                // In a real implementation, you would check collisions with each node
                editor_state.selected_node_index += 1
                if editor_state.selected_node_index > 5 {  // Just cycle through 5 demo nodes
                    editor_state.selected_node_index = 0
                }
                log_debug(.ENGINE, "Selected node: %d", editor_state.selected_node_index)
            }
        }
        
        return true
    } else {
        return false
    }
}

// Render the editor UI (only in debug mode)
editor_render :: proc() {
    when ODIN_DEBUG {
        if !editor_state.initialized || !editor_state.active {
            return
        }
        
        // Draw panels background
        raylib.DrawRectangleRec(editor_state.scene_tree_rect, PANEL_COLOR)
        raylib.DrawRectangleLinesEx(editor_state.scene_tree_rect, 1, PANEL_BORDER_COLOR)
        
        raylib.DrawRectangleRec(editor_state.inspector_rect, PANEL_COLOR)
        raylib.DrawRectangleLinesEx(editor_state.inspector_rect, 1, PANEL_BORDER_COLOR)
        
        // Draw panel titles
        title_x := editor_state.scene_tree_rect.x + 10
        title_y := editor_state.scene_tree_rect.y + 10
        raylib.DrawText("Scene Tree", i32(title_x), i32(title_y), 20, TITLE_COLOR)
        
        inspector_title_x := editor_state.inspector_rect.x + 10
        inspector_title_y := editor_state.inspector_rect.y + 10
        raylib.DrawText("Inspector", i32(inspector_title_x), i32(inspector_title_y), 20, TITLE_COLOR)
        
        // Draw viewport border
        raylib.DrawRectangleLinesEx(editor_state.viewport_rect, 2, PANEL_BORDER_COLOR)
        
        // Draw scene tree nodes
        node_names := []string{"Root", "Camera", "Player", "Level", "Lights", "Effects"}
        start_y := title_y + 30
        
        for i := 0; i < len(node_names); i += 1 {
            text_y := start_y + f32(i * 25)
            text_color := TEXT_COLOR
            
            // Highlight selected node
            if i == editor_state.selected_node_index {
                node_rect := raylib.Rectangle{
                    x = editor_state.scene_tree_rect.x + 5,
                    y = text_y - 2,
                    width = editor_state.scene_tree_rect.width - 10,
                    height = 24,
                }
                raylib.DrawRectangleRec(node_rect, SELECTED_COLOR)
                text_color = HIGHLIGHTED_TEXT_COLOR
            }
            
            // Add icons to nodes based on type - using small circles as simple icons
            icon_x := editor_state.scene_tree_rect.x + 15
            icon_y := text_y + 10
            
            // Draw different icons based on node type
            icon_color := raylib.LIGHTGRAY
            if i == 0 { // Root
                icon_color = raylib.GREEN
            } else if i == 1 { // Camera
                icon_color = raylib.SKYBLUE
            } else if i == 2 { // Player
                icon_color = raylib.RED
            }
            
            raylib.DrawCircle(i32(icon_x), i32(icon_y), 4, icon_color)
            
            // Draw node text
            raylib.DrawText(strings.clone_to_cstring(node_names[i]), i32(icon_x + 15), i32(text_y), 20, text_color)
        }
        
        // Draw inspector contents if a node is selected
        if editor_state.selected_node_index >= 0 && editor_state.selected_node_index < len(node_names) {
            selected_name := node_names[editor_state.selected_node_index]
            content_y := inspector_title_y + 30
            
            // Draw name field with outline
            raylib.DrawRectangleLines(
                i32(inspector_title_x), 
                i32(content_y),
                i32(editor_state.inspector_rect.width - 20),
                30,
                raylib.DARKGRAY
            )
            
            raylib.DrawText(
                strings.clone_to_cstring(fmt.tprintf("Name: %s", selected_name)),
                i32(inspector_title_x + 10), 
                i32(content_y + 5), 
                18, 
                TEXT_COLOR
            )
            
            // Transform section
            transform_y := content_y + 40
            
            // Header with box
            raylib.DrawRectangleLines(
                i32(inspector_title_x),
                i32(transform_y),
                i32(editor_state.inspector_rect.width - 20),
                25,
                raylib.DARKGRAY
            )
            
            raylib.DrawText(
                "Transform",
                i32(inspector_title_x + 10),
                i32(transform_y + 5),
                18,
                TEXT_COLOR
            )
            
            // Position
            position_y := transform_y + 35
            raylib.DrawText(
                strings.clone_to_cstring(fmt.tprintf("Position: %.1f, %.1f, %.1f", 
                    f32(editor_state.selected_node_index), 0.0, 0.0)),
                i32(inspector_title_x + 20),
                i32(position_y),
                16,
                TEXT_COLOR
            )
            
            // Rotation
            rotation_y := position_y + 25
            raylib.DrawText(
                "Rotation: 0.0, 0.0, 0.0",
                i32(inspector_title_x + 20),
                i32(rotation_y),
                16,
                TEXT_COLOR
            )
            
            // Scale
            scale_y := rotation_y + 25
            raylib.DrawText(
                "Scale: 1.0, 1.0, 1.0",
                i32(inspector_title_x + 20),
                i32(scale_y),
                16,
                TEXT_COLOR
            )
            
            // Other properties section
            props_y := scale_y + 40
            
            // Header with box
            raylib.DrawRectangleLines(
                i32(inspector_title_x),
                i32(props_y),
                i32(editor_state.inspector_rect.width - 20),
                25,
                raylib.DARKGRAY
            )
            
            raylib.DrawText(
                "Properties",
                i32(inspector_title_x + 10),
                i32(props_y + 5),
                18,
                TEXT_COLOR
            )
            
            // Visibility toggle - fake checkbox
            vis_y := props_y + 35
            raylib.DrawRectangleLines(
                i32(inspector_title_x + 20),
                i32(vis_y),
                16,
                16,
                TEXT_COLOR
            )
            
            // Fill checkbox if enabled
            raylib.DrawRectangle(
                i32(inspector_title_x + 23),
                i32(vis_y + 3),
                10,
                10,
                TEXT_COLOR
            )
            
            raylib.DrawText(
                "Visible",
                i32(inspector_title_x + 45),
                i32(vis_y),
                16,
                TEXT_COLOR
            )
        }
        
        // Draw viewport info
        raylib.DrawText(
            strings.clone_to_cstring(fmt.tprintf("Viewport: %dx%d", 
                i32(editor_state.viewport_rect.width), 
                i32(editor_state.viewport_rect.height))),
            i32(editor_state.viewport_rect.x + 10),
            i32(editor_state.viewport_rect.y + 10),
            20,
            TEXT_COLOR
        )
    }
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
    when ODIN_DEBUG {
        if !editor_state.initialized {
            return
        }
        
        log_info(.ENGINE, "Shutting down editor")
        editor_state.initialized = false
        editor_state.active = false
    }
}

// Update editor panel layouts based on window size
editor_update_layout :: proc() {
    when ODIN_DEBUG {
        screen_width := f32(raylib.GetScreenWidth())
        screen_height := f32(raylib.GetScreenHeight())
        
        // Calculate panel sizes
        scene_tree_height := screen_height * SCENE_TREE_HEIGHT
        
        // Scene tree panel (left top)
        editor_state.scene_tree_rect = raylib.Rectangle{
            x = 0,
            y = 0,
            width = PANEL_WIDTH,
            height = scene_tree_height,
        }
        
        // Inspector panel (left bottom)
        editor_state.inspector_rect = raylib.Rectangle{
            x = 0,
            y = scene_tree_height,
            width = PANEL_WIDTH,
            height = screen_height - scene_tree_height,
        }
        
        // Viewport (main area)
        editor_state.viewport_rect = raylib.Rectangle{
            x = PANEL_WIDTH,
            y = 0,
            width = screen_width - PANEL_WIDTH,
            height = screen_height,
        }
    }
}

// Toggle editor visibility
editor_toggle :: proc() -> bool {
    when ODIN_DEBUG {
        if !editor_state.initialized {
            editor_init()
        }
        
        editor_state.active = !editor_state.active
        log_info(.ENGINE, "Editor active: %v", editor_state.active)
        return editor_state.active
    } else {
        return false
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