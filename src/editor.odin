#+feature dynamic-literals
package main

import "core:strings"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"
import "core:os"
import "core:strconv"

// Constants for editor layout
PANEL_WIDTH :: 300 // pixels
FONT_SIZE :: 18
SMALL_FONT_SIZE :: 16
LABEL_WIDTH :: 20
FIELD_WIDTH :: 60
FIELD_HEIGHT :: 24
FIELD_SPACING :: 5

// ImGUI-style editor theme colors (variables, not constants)
PANEL_COLOR: raylib.Color
PANEL_BORDER_COLOR: raylib.Color
TITLE_COLOR: raylib.Color
SELECTED_COLOR: raylib.Color
HOVER_COLOR: raylib.Color
TEXT_COLOR: raylib.Color
HIGHLIGHTED_TEXT_COLOR: raylib.Color
TITLE_BAR_COLOR: raylib.Color

// Header/section colors
HEADER_COLOR: raylib.Color
HEADER_TEXT_COLOR: raylib.Color

// Input field colors
INPUT_BG_COLOR: raylib.Color
INPUT_BORDER_COLOR: raylib.Color
INPUT_TEXT_COLOR: raylib.Color
INPUT_ACTIVE_BG_COLOR: raylib.Color
INPUT_SELECTION_COLOR: raylib.Color

// Define colors for axis labels
AXIS_X_COLOR: raylib.Color
AXIS_Y_COLOR: raylib.Color
AXIS_Z_COLOR: raylib.Color
AXIS_LABEL_TEXT_COLOR: raylib.Color

// Editor tabs
Editor_Tab :: enum {
    SCENE,
    ASSETS,
}

// Editor tools
Editor_Tool :: enum {
    SELECT,
    MOVE,
    ROTATE,
    SCALE,
}

// Editor mode
Editor_Mode :: enum {
    EDIT,
    PLAY,
}

// Editor state
Editor_State :: struct {
    active: bool,
    initialized: bool,
    
    // Panel rectangles
    scene_tree_rect: raylib.Rectangle,
    inspector_rect: raylib.Rectangle,
    viewport_rect: raylib.Rectangle,
    
    // Selected entity
    selected_entity: Entity,
    
    // Current tab and tool
    current_tab: Editor_Tab,
    current_tool: Editor_Tool,
    current_mode: Editor_Mode,
    
    // Inspector scroll position
    inspector_scroll: f32,
    
    // Scene tree scroll position
    scene_tree_scroll: f32,
    
    // Assets panel scroll
    assets_scroll: f32,
    
    // Editor font
    ui_font: raylib.Font,
    
    // For input fields
    active_input_field: string,
    input_text_buffer: [128]u8,
    input_text_length: i32,
    is_text_selected: bool,  // Flag to track if text is selected
}

editor_state: Editor_State

// Initialize the editor (only in debug mode)
editor_init :: proc() -> bool {
    when ODIN_DEBUG {
        if editor_state.initialized {
            return true
        }
        
        log_info(.ENGINE, "Initializing editor")
        
        // Initialize colors
        PANEL_COLOR = raylib.ColorFromNormalized({0.15, 0.15, 0.15, 1.0})  // Dark gray background
        PANEL_BORDER_COLOR = raylib.ColorFromNormalized({0.30, 0.30, 0.30, 1.0})  // Light gray border
        TITLE_COLOR = raylib.ColorFromNormalized({0.83, 0.83, 0.83, 1.0})  // Light gray text
        SELECTED_COLOR = raylib.ColorFromNormalized({0.24, 0.24, 0.28, 1.0})  // Slightly lighter background for selected items
        HOVER_COLOR = raylib.ColorFromNormalized({0.20, 0.20, 0.24, 1.0})  // Hover color
        TEXT_COLOR = raylib.ColorFromNormalized({0.83, 0.83, 0.83, 1.0})  // Light gray text
        HIGHLIGHTED_TEXT_COLOR = raylib.WHITE
        TITLE_BAR_COLOR = raylib.ColorFromNormalized({0.22, 0.22, 0.22, 1.0})  // Slightly lighter for title bars
        
        HEADER_COLOR = raylib.ColorFromNormalized({0.19, 0.19, 0.19, 1.0})
        HEADER_TEXT_COLOR = raylib.ColorFromNormalized({0.83, 0.83, 0.83, 1.0})
        
        INPUT_BG_COLOR = raylib.ColorFromNormalized({0.10, 0.10, 0.10, 1.0})  // Darker for input fields
        INPUT_BORDER_COLOR = raylib.ColorFromNormalized({0.25, 0.25, 0.25, 1.0})
        INPUT_TEXT_COLOR = raylib.ColorFromNormalized({0.83, 0.83, 0.83, 1.0})
        INPUT_ACTIVE_BG_COLOR = raylib.ColorFromNormalized({0.15, 0.15, 0.15, 1.0})
        INPUT_SELECTION_COLOR = raylib.ColorFromNormalized({0.27, 0.36, 0.47, 1.0})  // Blue-ish selection color
        
        AXIS_X_COLOR = raylib.ColorFromNormalized({0.90, 0.29, 0.23, 1.0})  // Red but more muted
        AXIS_Y_COLOR = raylib.ColorFromNormalized({0.44, 0.75, 0.35, 1.0})  // Green but more muted
        AXIS_Z_COLOR = raylib.ColorFromNormalized({0.25, 0.58, 0.98, 1.0})  // Blue but more muted
        AXIS_LABEL_TEXT_COLOR = raylib.WHITE
        
        // Set default state
        editor_state.active = true
        editor_state.initialized = true
        editor_state.selected_entity = 0  // No entity selected (0 is invalid ID)
        editor_state.current_tab = .SCENE
        editor_state.current_tool = .SELECT
        editor_state.current_mode = .EDIT
        editor_state.inspector_scroll = 0
        editor_state.scene_tree_scroll = 0
        editor_state.assets_scroll = 0
        
        // Load UI font
        font_path := "assets/fonts/UbuntuNerdFont-Regular.ttf"
        if os.exists(font_path) {
            editor_state.ui_font = raylib.LoadFontEx(strings.clone_to_cstring(font_path), FONT_SIZE, nil, 0)
            raylib.SetTextureFilter(editor_state.ui_font.texture, .BILINEAR)
        } else {
            log_warning(.ENGINE, "UI font not found at '%s', using default font", font_path)
            editor_state.ui_font = raylib.GetFontDefault()
        }
        
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
        
        // Handle key shortcuts
        if raylib.IsKeyPressed(.S) && raylib.IsKeyDown(.LEFT_CONTROL) {
            // Ctrl+S: Save scene
            scene_save()
        }
        
        if raylib.IsKeyPressed(.N) && raylib.IsKeyDown(.LEFT_CONTROL) {
            // Ctrl+N: New scene
            scene_new("New Scene")
        }
        
        // Handle tool selection
        if raylib.IsKeyPressed(.Q) {
            editor_state.current_tool = .SELECT
        } else if raylib.IsKeyPressed(.W) {
            editor_state.current_tool = .MOVE
        } else if raylib.IsKeyPressed(.E) {
            editor_state.current_tool = .ROTATE
        } else if raylib.IsKeyPressed(.R) {
            editor_state.current_tool = .SCALE
        }
        
        // Handle input fields if an active field exists
        if editor_state.active_input_field != "" {
            // Handle escape to cancel editing
            if raylib.IsKeyPressed(.ESCAPE) {
                editor_state.active_input_field = ""
                editor_state.input_text_length = 0
                editor_state.is_text_selected = false
            }
            
            // Handle enter to apply changes
            if raylib.IsKeyPressed(.ENTER) || raylib.IsKeyPressed(.KP_ENTER) {
                // Parse the input and apply it to the entity's transform
                if editor_state.selected_entity != 0 {
                    transform := ecs_get_transform(editor_state.selected_entity)
                    if transform != nil {
                        input_text := string(editor_state.input_text_buffer[:editor_state.input_text_length])
                        value, ok := strconv.parse_f32(input_text)
                        
                        if ok {
                            // Apply the value based on which field was active
                            field_parts := strings.split(editor_state.active_input_field, "_")
                            defer delete(field_parts)
                            
                            if len(field_parts) >= 2 {
                                field_type := field_parts[0]
                                axis := field_parts[1]
                                
                                axis_index := -1
                                if axis == "x" {
                                    axis_index = 0
                                } else if axis == "y" {
                                    axis_index = 1
                                } else if axis == "z" {
                                    axis_index = 2
                                }
                                
                                if axis_index >= 0 {
                                    if field_type == "pos" {
                                        transform.position[axis_index] = value
                                        scene_mark_dirty()
                                    } else if field_type == "rot" {
                                        transform.rotation[axis_index] = value
                                        scene_mark_dirty()
                                    } else if field_type == "scale" {
                                        transform.scale[axis_index] = value
                                        scene_mark_dirty()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Clear the active field
                editor_state.active_input_field = ""
                editor_state.input_text_length = 0
                editor_state.is_text_selected = false
            }
            
            // Handle text input for the active field
            key := raylib.GetCharPressed()
            for key > 0 {
                // Only allow digits, decimal point, minus sign
                if (key >= '0' && key <= '9') || key == '.' || key == '-' {
                    // If text is selected, clear the buffer first
                    if editor_state.is_text_selected {
                        editor_state.input_text_length = 0
                        editor_state.is_text_selected = false
                    }
                    
                    // Add character to input buffer if there's room
                    if editor_state.input_text_length < len(editor_state.input_text_buffer) - 1 {
                        editor_state.input_text_buffer[editor_state.input_text_length] = u8(key)
                        editor_state.input_text_length += 1
                    }
                }
                key = raylib.GetCharPressed()
            }
            
            // Handle backspace
            if raylib.IsKeyPressed(.BACKSPACE) {
                // If text is selected, clear all text
                if editor_state.is_text_selected {
                    editor_state.input_text_length = 0
                    editor_state.is_text_selected = false
                } else if editor_state.input_text_length > 0 {
                    // Otherwise delete last character
                    editor_state.input_text_length -= 1
                }
            }
        }
        
        // Handle input (e.g., selecting entities in scene tree)
        if raylib.IsMouseButtonPressed(.LEFT) {
            mouse_pos := raylib.GetMousePosition()
            
            // Check if clicked in scene tree area
            if raylib.CheckCollisionPointRec(mouse_pos, editor_state.scene_tree_rect) {
                // Get all entities in the scene
                scene_entities := scene_get_entities()
                defer delete(scene_entities)
                
                // Calculate available display area for entities
                title_height := 35
                item_height := 28
                content_y := editor_state.scene_tree_rect.y + f32(title_height)
                
                // Check click against each entity row
                for i := 0; i < len(scene_entities); i += 1 {
                    entity := scene_entities[i]
                    row_y := content_y + f32(i * item_height) - editor_state.scene_tree_scroll
                    
                    if row_y >= content_y && row_y <= editor_state.scene_tree_rect.y + editor_state.scene_tree_rect.height {
                        row_rect := raylib.Rectangle{
                            x = editor_state.scene_tree_rect.x + 5,
                            y = row_y - 2,
                            width = editor_state.scene_tree_rect.width - 10,
                            height = f32(item_height),
                        }
                        
                        if raylib.CheckCollisionPointRec(mouse_pos, row_rect) {
                            editor_state.selected_entity = entity
                            log_debug(.ENGINE, "Selected entity: %d", entity)
                            break
                        }
                    }
                }
            }
            
            // Check if clicked in inspector area and check for transform input fields
            if raylib.CheckCollisionPointRec(mouse_pos, editor_state.inspector_rect) && editor_state.selected_entity != 0 {
                transform := ecs_get_transform(editor_state.selected_entity)
                if transform != nil {
                    // Calculate positions for the inspector fields
                    title_bar_height := 30
                    inspector_title_x := editor_state.inspector_rect.x + 20
                    content_y := editor_state.inspector_rect.y + f32(title_bar_height) + 10
                    transform_y := content_y + 40
                    fields_start_x := inspector_title_x + 20
                    
                    // Position fields
                    position_y := transform_y + 35
                    position_fields_y := position_y + 20
                    
                    // Calculate X, Y, Z field positions
                    y_field_x := fields_start_x + LABEL_WIDTH + FIELD_WIDTH + FIELD_SPACING
                    z_field_x := y_field_x + LABEL_WIDTH + FIELD_WIDTH + FIELD_SPACING
                    
                    // Rotation fields
                    rotation_y := position_fields_y + FIELD_HEIGHT + 15
                    rotation_fields_y := rotation_y + 20
                    
                    // Scale fields
                    scale_y := rotation_fields_y + FIELD_HEIGHT + 15
                    scale_fields_y := scale_y + 20
                    
                    // Position input fields
                    // X position field
                    x_pos_rect := raylib.Rectangle{
                        x = fields_start_x + LABEL_WIDTH,
                        y = position_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, x_pos_rect) {
                        editor_state.active_input_field = fmt.tprintf("pos_x_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        x_text := fmt.tprintf("%.2f", transform.position[0])
                        for i := 0; i < len(x_text); i += 1 {
                            editor_state.input_text_buffer[i] = x_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Y position field
                    y_pos_rect := raylib.Rectangle{
                        x = y_field_x + LABEL_WIDTH,
                        y = position_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, y_pos_rect) {
                        editor_state.active_input_field = fmt.tprintf("pos_y_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        y_text := fmt.tprintf("%.2f", transform.position[1])
                        for i := 0; i < len(y_text); i += 1 {
                            editor_state.input_text_buffer[i] = y_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Z position field
                    z_pos_rect := raylib.Rectangle{
                        x = z_field_x + LABEL_WIDTH,
                        y = position_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, z_pos_rect) {
                        editor_state.active_input_field = fmt.tprintf("pos_z_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        z_text := fmt.tprintf("%.2f", transform.position[2])
                        for i := 0; i < len(z_text); i += 1 {
                            editor_state.input_text_buffer[i] = z_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Rotation input fields
                    // X rotation field
                    x_rot_rect := raylib.Rectangle{
                        x = fields_start_x + LABEL_WIDTH,
                        y = rotation_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, x_rot_rect) {
                        editor_state.active_input_field = fmt.tprintf("rot_x_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        x_text := fmt.tprintf("%.2f", transform.rotation[0])
                        for i := 0; i < len(x_text); i += 1 {
                            editor_state.input_text_buffer[i] = x_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Y rotation field
                    y_rot_rect := raylib.Rectangle{
                        x = y_field_x + LABEL_WIDTH,
                        y = rotation_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, y_rot_rect) {
                        editor_state.active_input_field = fmt.tprintf("rot_y_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        y_text := fmt.tprintf("%.2f", transform.rotation[1])
                        for i := 0; i < len(y_text); i += 1 {
                            editor_state.input_text_buffer[i] = y_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Z rotation field
                    z_rot_rect := raylib.Rectangle{
                        x = z_field_x + LABEL_WIDTH,
                        y = rotation_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, z_rot_rect) {
                        editor_state.active_input_field = fmt.tprintf("rot_z_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        z_text := fmt.tprintf("%.2f", transform.rotation[2])
                        for i := 0; i < len(z_text); i += 1 {
                            editor_state.input_text_buffer[i] = z_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Scale input fields
                    // X scale field
                    x_scale_rect := raylib.Rectangle{
                        x = fields_start_x + LABEL_WIDTH,
                        y = scale_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, x_scale_rect) {
                        editor_state.active_input_field = fmt.tprintf("scale_x_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        x_text := fmt.tprintf("%.2f", transform.scale[0])
                        for i := 0; i < len(x_text); i += 1 {
                            editor_state.input_text_buffer[i] = x_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Y scale field
                    y_scale_rect := raylib.Rectangle{
                        x = y_field_x + LABEL_WIDTH,
                        y = scale_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, y_scale_rect) {
                        editor_state.active_input_field = fmt.tprintf("scale_y_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        y_text := fmt.tprintf("%.2f", transform.scale[1])
                        for i := 0; i < len(y_text); i += 1 {
                            editor_state.input_text_buffer[i] = y_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                    
                    // Z scale field
                    z_scale_rect := raylib.Rectangle{
                        x = z_field_x + LABEL_WIDTH,
                        y = scale_fields_y,
                        width = FIELD_WIDTH,
                        height = FIELD_HEIGHT,
                    }
                    if raylib.CheckCollisionPointRec(mouse_pos, z_scale_rect) {
                        editor_state.active_input_field = fmt.tprintf("scale_z_%d", editor_state.selected_entity)
                        editor_state.input_text_length = 0
                        z_text := fmt.tprintf("%.2f", transform.scale[2])
                        for i := 0; i < len(z_text); i += 1 {
                            editor_state.input_text_buffer[i] = z_text[i]
                            editor_state.input_text_length += 1
                        }
                        editor_state.is_text_selected = true
                    }
                }
            } else if editor_state.active_input_field != "" {
                // If clicked outside of any input field, commit any active edits
                // Similar to pressing Enter
                if editor_state.selected_entity != 0 {
                    transform := ecs_get_transform(editor_state.selected_entity)
                    if transform != nil {
                        input_text := string(editor_state.input_text_buffer[:editor_state.input_text_length])
                        value, ok := strconv.parse_f32(input_text)
                        
                        if ok {
                            // Apply the value based on which field was active
                            field_parts := strings.split(editor_state.active_input_field, "_")
                            defer delete(field_parts)
                            
                            if len(field_parts) >= 2 {
                                field_type := field_parts[0]
                                axis := field_parts[1]
                                
                                axis_index := -1
                                if axis == "x" {
                                    axis_index = 0
                                } else if axis == "y" {
                                    axis_index = 1
                                } else if axis == "z" {
                                    axis_index = 2
                                }
                                
                                if axis_index >= 0 {
                                    if field_type == "pos" {
                                        transform.position[axis_index] = value
                                        scene_mark_dirty()
                                    } else if field_type == "rot" {
                                        transform.rotation[axis_index] = value
                                        scene_mark_dirty()
                                    } else if field_type == "scale" {
                                        transform.scale[axis_index] = value
                                        scene_mark_dirty()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Clear the active field
                editor_state.active_input_field = ""
                editor_state.input_text_length = 0
                editor_state.is_text_selected = false
            }
            
            // Handle clicking in viewport for 3D object selection
            // TODO: Implement 3D picking
        }
        
        // Handle mouse wheel for scrolling
        wheel_move := raylib.GetMouseWheelMove()
        if wheel_move != 0 {
            mouse_pos := raylib.GetMousePosition()
            
            // Scroll scene tree
            if raylib.CheckCollisionPointRec(mouse_pos, editor_state.scene_tree_rect) {
                editor_state.scene_tree_scroll -= wheel_move * 30
                if editor_state.scene_tree_scroll < 0 {
                    editor_state.scene_tree_scroll = 0
                }
                // TODO: Add max scroll limit based on content
            }
            
            // Scroll inspector
            if raylib.CheckCollisionPointRec(mouse_pos, editor_state.inspector_rect) {
                editor_state.inspector_scroll -= wheel_move * 30
                if editor_state.inspector_scroll < 0 {
                    editor_state.inspector_scroll = 0
                }
                // TODO: Add max scroll limit based on content
            }
        }
        
        return true
    }
    
    return false
}

// Helper to draw text with the editor font
draw_text :: proc(text: cstring, x, y: i32, size: f32, color: raylib.Color) {
    when ODIN_DEBUG {
        if editor_state.ui_font.texture.id > 0 {
            raylib.DrawTextEx(editor_state.ui_font, text, {f32(x), f32(y)}, size, 1.0, color)
        } else {
            raylib.DrawText(text, x, y, i32(size), color)
        }
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
        
        // Draw panel title bars
        title_bar_height :: 30
        
        // Scene tree title bar
        raylib.DrawRectangle(
            i32(editor_state.scene_tree_rect.x), 
            i32(editor_state.scene_tree_rect.y),
            i32(editor_state.scene_tree_rect.width),
            title_bar_height,
            TITLE_BAR_COLOR
        )
        
        // Inspector title bar
        raylib.DrawRectangle(
            i32(editor_state.inspector_rect.x), 
            i32(editor_state.inspector_rect.y),
            i32(editor_state.inspector_rect.width),
            title_bar_height,
            TITLE_BAR_COLOR
        )
        
        // Draw panel titles
        title_x := editor_state.scene_tree_rect.x + 10
        title_y := editor_state.scene_tree_rect.y + 8  // Centered in title bar
        draw_text("SCENE HIERARCHY", i32(title_x), i32(title_y), SMALL_FONT_SIZE, TITLE_COLOR)
        
        inspector_title_x := editor_state.inspector_rect.x + 10
        inspector_title_y := editor_state.inspector_rect.y + 8  // Centered in title bar
        draw_text("INSPECTOR", i32(inspector_title_x), i32(inspector_title_y), SMALL_FONT_SIZE, TITLE_COLOR)
        
        // Draw viewport border
        raylib.DrawRectangleLinesEx(editor_state.viewport_rect, 1, PANEL_BORDER_COLOR)
        
        // Draw scene tree with actual entities
        if scene_is_loaded() {
            scene_entities := scene_get_entities()
            defer delete(scene_entities)
            
            start_y := editor_state.scene_tree_rect.y + f32(title_bar_height) + 5
            
            // Show scene name
            scene_name_y := start_y + 5
            scene_name_bg := raylib.Rectangle{
                x = editor_state.scene_tree_rect.x + 5,
                y = scene_name_y - 2,
                width = editor_state.scene_tree_rect.width - 10,
                height = 25,
            }
            raylib.DrawRectangleRec(scene_name_bg, HEADER_COLOR)
            
            draw_text(
                strings.clone_to_cstring(fmt.tprintf("Scene: %s%s", 
                    current_scene.name, 
                    scene_is_dirty() ? "*" : "")),
                i32(editor_state.scene_tree_rect.x + 10),
                i32(scene_name_y),
                SMALL_FONT_SIZE,
                HEADER_TEXT_COLOR
            )
            
            // Draw each entity in the scene
            entity_list_start_y := scene_name_y + 30
            for i := 0; i < len(scene_entities); i += 1 {
                entity := scene_entities[i]
                text_y := entity_list_start_y + f32(i * 28) - editor_state.scene_tree_scroll
                
                // Skip if outside visible area
                if text_y < start_y || text_y > editor_state.scene_tree_rect.y + editor_state.scene_tree_rect.height - 10 {
                    continue
                }
                
                text_color := TEXT_COLOR
                
                // Highlight selected entity
                if entity == editor_state.selected_entity {
                    node_rect := raylib.Rectangle{
                        x = editor_state.scene_tree_rect.x + 5,
                        y = text_y - 2,
                        width = editor_state.scene_tree_rect.width - 10,
                        height = 24,
                    }
                    raylib.DrawRectangleRec(node_rect, SELECTED_COLOR)
                    raylib.DrawRectangleLinesEx(node_rect, 1, PANEL_BORDER_COLOR)
                    text_color = HIGHLIGHTED_TEXT_COLOR
                }
                
                // Get entity name or ID if no name
                entity_name := fmt.tprintf("Entity %d", entity)
                
                // Determine entity type based on components
                icon_x := editor_state.scene_tree_rect.x + 15
                icon_y := text_y + 10
                icon_color := raylib.LIGHTGRAY
                
                if ecs_has_component(entity, .CAMERA) {
                    icon_color = AXIS_Z_COLOR  // Use our muted blue
                    camera := ecs_get_camera(entity)
                    if camera != nil && camera.is_main {
                        entity_name = "Main Camera"
                    } else {
                        entity_name = "Camera"
                    }
                } else if ecs_has_component(entity, .LIGHT) {
                    icon_color = AXIS_Y_COLOR  // Use our muted green
                    light := ecs_get_light(entity)
                    if light != nil {
                        #partial switch light.light_type {
                            case .DIRECTIONAL: entity_name = "Directional Light"
                            case .POINT: entity_name = "Point Light"
                            case .SPOT: entity_name = "Spot Light"
                        }
                    } else {
                        entity_name = "Light"
                    }
                } else if ecs_has_component(entity, .RENDERER) {
                    icon_color = AXIS_X_COLOR  // Use our muted red
                    entity_name = "Mesh"
                } else if i == 0 { // Assume first entity might be root
                    icon_color = AXIS_Y_COLOR  // Use our muted green
                    entity_name = "Root"
                }
                
                raylib.DrawCircle(i32(icon_x), i32(icon_y), 4, icon_color)
                
                // Draw entity name
                draw_text(
                    strings.clone_to_cstring(entity_name),
                    i32(icon_x + 15),
                    i32(text_y + 2),  // Better vertical alignment
                    SMALL_FONT_SIZE,
                    text_color
                )
            }
        } else {
            // No scene loaded
            draw_text(
                "No scene loaded",
                i32(title_x + 20),
                i32(editor_state.scene_tree_rect.y + 50),
                SMALL_FONT_SIZE,
                TEXT_COLOR
            )
        }
        
        // Draw inspector contents if an entity is selected
        if editor_state.selected_entity != 0 {
            content_y := editor_state.inspector_rect.y + f32(title_bar_height) + 10
            
            // Get entity name from type
            entity_name := "Entity"
            if ecs_has_component(editor_state.selected_entity, .CAMERA) {
                camera := ecs_get_camera(editor_state.selected_entity)
                if camera != nil && camera.is_main {
                    entity_name = "Main Camera"
                } else {
                    entity_name = "Camera"
                }
            } else if ecs_has_component(editor_state.selected_entity, .LIGHT) {
                light := ecs_get_light(editor_state.selected_entity)
                if light != nil {
                    #partial switch light.light_type {
                        case .DIRECTIONAL: entity_name = "Directional Light"
                        case .POINT: entity_name = "Point Light"
                        case .SPOT: entity_name = "Spot Light"
                    }
                } else {
                    entity_name = "Light"
                }
            } else if ecs_has_component(editor_state.selected_entity, .RENDERER) {
                entity_name = "Mesh"
            }
            
            // Draw name field with modern styling
            name_bg := raylib.Rectangle{
                x = inspector_title_x, 
                y = content_y,
                width = editor_state.inspector_rect.width - 20,
                height = 30,
            }
            raylib.DrawRectangleRec(name_bg, HEADER_COLOR)
            raylib.DrawRectangleLinesEx(name_bg, 1, PANEL_BORDER_COLOR)
            
            draw_text(
                strings.clone_to_cstring(fmt.tprintf("%s #%d", entity_name, editor_state.selected_entity)),
                i32(inspector_title_x + 10), 
                i32(content_y + 8),  // Better vertical centering
                SMALL_FONT_SIZE, 
                HEADER_TEXT_COLOR
            )
            
            // Transform section if entity has transform
            if transform := ecs_get_transform(editor_state.selected_entity); transform != nil {
                transform_y := content_y + 40
                
                // Component header with modern styling
                component_header := raylib.Rectangle{
                    x = inspector_title_x,
                    y = transform_y,
                    width = editor_state.inspector_rect.width - 20,
                    height = 25,
                }
                raylib.DrawRectangleRec(component_header, TITLE_BAR_COLOR)
                raylib.DrawRectangleLinesEx(component_header, 1, PANEL_BORDER_COLOR)
                
                draw_text(
                    "Transform",
                    i32(inspector_title_x + 10),
                    i32(transform_y + 5),  // Better vertical centering
                    SMALL_FONT_SIZE,
                    TITLE_COLOR
                )
                
                // Input field dimensions
                label_width :: 20
                field_width :: 60
                field_height :: 24
                field_spacing :: 5
                fields_start_x := inspector_title_x + 20
                
                // Position
                position_y := transform_y + 35
                draw_text(
                    "Position",
                    i32(inspector_title_x + 20),
                    i32(position_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                position_fields_y := position_y + 20
                
                // X Position field with red label
                raylib.DrawRectangle(
                    i32(fields_start_x), 
                    i32(position_fields_y), 
                    label_width, 
                    field_height, 
                    AXIS_X_COLOR
                )
                draw_text(
                    "X",
                    i32(fields_start_x + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    AXIS_LABEL_TEXT_COLOR
                )
                
                // X input field with modern styling
                x_field_key := fmt.tprintf("pos_x_%d", editor_state.selected_entity)
                x_field_active := editor_state.active_input_field == x_field_key
                x_field_bg := x_field_active ? INPUT_ACTIVE_BG_COLOR : INPUT_BG_COLOR
                
                x_field_rect := raylib.Rectangle{
                    x = fields_start_x + label_width,
                    y = position_fields_y,
                    width = field_width,
                    height = field_height,
                }
                raylib.DrawRectangleRec(x_field_rect, x_field_bg)
                raylib.DrawRectangleLinesEx(x_field_rect, 1, INPUT_BORDER_COLOR)
                
                // Draw text selection highlight if this field is active and text is selected
                if x_field_active && editor_state.is_text_selected {
                    // Get text width for selection background
                    x_display := fmt.tprintf("%.2f", transform.position[0])
                    text_width := raylib.MeasureTextEx(editor_state.ui_font, strings.clone_to_cstring(x_display), SMALL_FONT_SIZE, 1.0).x
                    
                    // Draw selection rectangle
                    raylib.DrawRectangle(
                        i32(fields_start_x + label_width + 5), 
                        i32(position_fields_y + 2), 
                        i32(text_width), 
                        field_height - 4, 
                        INPUT_SELECTION_COLOR
                    )
                }
                
                x_display := fmt.tprintf("%.2f", transform.position[0])
                if x_field_active {
                    // If this field is active, show input buffer instead
                    x_display = string(editor_state.input_text_buffer[:editor_state.input_text_length])
                }
                
                draw_text(
                    strings.clone_to_cstring(x_display),
                    i32(fields_start_x + label_width + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    x_field_active && editor_state.is_text_selected ? HIGHLIGHTED_TEXT_COLOR : INPUT_TEXT_COLOR
                )
                
                // Y Position field with green label
                y_field_x := fields_start_x + label_width + field_width + field_spacing
                raylib.DrawRectangle(
                    i32(y_field_x), 
                    i32(position_fields_y), 
                    label_width, 
                    field_height, 
                    AXIS_Y_COLOR
                )
                draw_text(
                    "Y",
                    i32(y_field_x + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    AXIS_LABEL_TEXT_COLOR
                )
                
                // Y input field with modern styling
                y_field_key := fmt.tprintf("pos_y_%d", editor_state.selected_entity)
                y_field_active := editor_state.active_input_field == y_field_key
                y_field_bg := y_field_active ? INPUT_ACTIVE_BG_COLOR : INPUT_BG_COLOR
                
                y_field_rect := raylib.Rectangle{
                    x = y_field_x + label_width,
                    y = position_fields_y,
                    width = field_width,
                    height = field_height,
                }
                raylib.DrawRectangleRec(y_field_rect, y_field_bg)
                raylib.DrawRectangleLinesEx(y_field_rect, 1, INPUT_BORDER_COLOR)
                
                // Draw text selection highlight if this field is active and text is selected
                if y_field_active && editor_state.is_text_selected {
                    // Get text width for selection background
                    y_display := fmt.tprintf("%.2f", transform.position[1])
                    text_width := raylib.MeasureTextEx(editor_state.ui_font, strings.clone_to_cstring(y_display), SMALL_FONT_SIZE, 1.0).x
                    
                    // Draw selection rectangle
                    raylib.DrawRectangle(
                        i32(y_field_x + label_width + 5), 
                        i32(position_fields_y + 2), 
                        i32(text_width), 
                        field_height - 4, 
                        INPUT_SELECTION_COLOR
                    )
                }
                
                y_display := fmt.tprintf("%.2f", transform.position[1])
                if y_field_active {
                    // If this field is active, show input buffer instead
                    y_display = string(editor_state.input_text_buffer[:editor_state.input_text_length])
                }
                
                draw_text(
                    strings.clone_to_cstring(y_display),
                    i32(y_field_x + label_width + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    y_field_active && editor_state.is_text_selected ? HIGHLIGHTED_TEXT_COLOR : INPUT_TEXT_COLOR
                )
                
                // Z Position field with blue label
                z_field_x := y_field_x + label_width + field_width + field_spacing
                raylib.DrawRectangle(
                    i32(z_field_x), 
                    i32(position_fields_y), 
                    label_width, 
                    field_height, 
                    AXIS_Z_COLOR
                )
                draw_text(
                    "Z",
                    i32(z_field_x + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    AXIS_LABEL_TEXT_COLOR
                )
                
                // Z input field with modern styling
                z_field_key := fmt.tprintf("pos_z_%d", editor_state.selected_entity)
                z_field_active := editor_state.active_input_field == z_field_key
                z_field_bg := z_field_active ? INPUT_ACTIVE_BG_COLOR : INPUT_BG_COLOR
                
                z_field_rect := raylib.Rectangle{
                    x = z_field_x + label_width,
                    y = position_fields_y,
                    width = field_width,
                    height = field_height,
                }
                raylib.DrawRectangleRec(z_field_rect, z_field_bg)
                raylib.DrawRectangleLinesEx(z_field_rect, 1, INPUT_BORDER_COLOR)
                
                // Draw text selection highlight if this field is active and text is selected
                if z_field_active && editor_state.is_text_selected {
                    // Get text width for selection background
                    z_display := fmt.tprintf("%.2f", transform.position[2])
                    text_width := raylib.MeasureTextEx(editor_state.ui_font, strings.clone_to_cstring(z_display), SMALL_FONT_SIZE, 1.0).x
                    
                    // Draw selection rectangle
                    raylib.DrawRectangle(
                        i32(z_field_x + label_width + 5), 
                        i32(position_fields_y + 2), 
                        i32(text_width), 
                        field_height - 4, 
                        INPUT_SELECTION_COLOR
                    )
                }
                
                z_display := fmt.tprintf("%.2f", transform.position[2])
                if z_field_active {
                    // If this field is active, show input buffer instead
                    z_display = string(editor_state.input_text_buffer[:editor_state.input_text_length])
                }
                
                draw_text(
                    strings.clone_to_cstring(z_display),
                    i32(z_field_x + label_width + 5),
                    i32(position_fields_y + 4),
                    SMALL_FONT_SIZE,
                    z_field_active && editor_state.is_text_selected ? HIGHLIGHTED_TEXT_COLOR : INPUT_TEXT_COLOR
                )
                
                content_y = position_fields_y + field_height + 20
            }
            
            // Camera component
            if camera := ecs_get_camera(editor_state.selected_entity); camera != nil {
                camera_y := content_y
                
                // Component header with modern styling
                component_header := raylib.Rectangle{
                    x = inspector_title_x,
                    y = camera_y,
                    width = editor_state.inspector_rect.width - 20,
                    height = 25,
                }
                raylib.DrawRectangleRec(component_header, TITLE_BAR_COLOR)
                raylib.DrawRectangleLinesEx(component_header, 1, PANEL_BORDER_COLOR)
                
                draw_text(
                    "Camera",
                    i32(inspector_title_x + 10),
                    i32(camera_y + 5),  // Better vertical centering
                    SMALL_FONT_SIZE,
                    TITLE_COLOR
                )
                
                // FOV
                fov_y := camera_y + 35
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("FOV: %.1f", camera.fov)),
                    i32(inspector_title_x + 20),
                    i32(fov_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Near/Far
                near_far_y := fov_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Near/Far: %.2f / %.1f", camera.near, camera.far)),
                    i32(inspector_title_x + 20),
                    i32(near_far_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Is main camera checkbox
                main_camera_y := near_far_y + 25
                raylib.DrawRectangleLines(
                    i32(inspector_title_x + 20),
                    i32(main_camera_y),
                    16,
                    16,
                    TEXT_COLOR
                )
                
                // Fill checkbox if enabled
                if camera.is_main {
                    raylib.DrawRectangle(
                        i32(inspector_title_x + 23),
                        i32(main_camera_y + 3),
                        10,
                        10,
                        TEXT_COLOR
                    )
                }
                
                draw_text(
                    "Main Camera",
                    i32(inspector_title_x + 45),
                    i32(main_camera_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                content_y = main_camera_y + 30
            }
            
            // Light component
            if light := ecs_get_light(editor_state.selected_entity); light != nil {
                light_y := content_y
                
                // Component header with modern styling
                component_header := raylib.Rectangle{
                    x = inspector_title_x,
                    y = light_y,
                    width = editor_state.inspector_rect.width - 20,
                    height = 25,
                }
                raylib.DrawRectangleRec(component_header, TITLE_BAR_COLOR)
                raylib.DrawRectangleLinesEx(component_header, 1, PANEL_BORDER_COLOR)
                
                draw_text(
                    "Light",
                    i32(inspector_title_x + 10),
                    i32(light_y + 5),  // Better vertical centering
                    SMALL_FONT_SIZE,
                    TITLE_COLOR
                )
                
                // Light type
                type_y := light_y + 35
                light_type_name := "Unknown"
                #partial switch light.light_type {
                    case .DIRECTIONAL: light_type_name = "Directional"
                    case .POINT: light_type_name = "Point"
                    case .SPOT: light_type_name = "Spot"
                }
                
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Type: %s", light_type_name)),
                    i32(inspector_title_x + 20),
                    i32(type_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Color
                color_y := type_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Color: %.2f, %.2f, %.2f", 
                        light.color[0], light.color[1], light.color[2])),
                    i32(inspector_title_x + 20),
                    i32(color_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Intensity
                intensity_y := color_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Intensity: %.2f", light.intensity)),
                    i32(inspector_title_x + 20),
                    i32(intensity_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                content_y = intensity_y + 30
            }
            
            // Renderer component
            if renderer := ecs_get_renderer(editor_state.selected_entity); renderer != nil {
                renderer_y := content_y
                
                // Component header with modern styling
                component_header := raylib.Rectangle{
                    x = inspector_title_x,
                    y = renderer_y,
                    width = editor_state.inspector_rect.width - 20,
                    height = 25,
                }
                raylib.DrawRectangleRec(component_header, TITLE_BAR_COLOR)
                raylib.DrawRectangleLinesEx(component_header, 1, PANEL_BORDER_COLOR)
                
                draw_text(
                    "Renderer",
                    i32(inspector_title_x + 10),
                    i32(renderer_y + 5),  // Better vertical centering
                    SMALL_FONT_SIZE,
                    TITLE_COLOR
                )
                
                // Mesh
                mesh_y := renderer_y + 35
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Mesh: %s", 
                        renderer.mesh == "" ? "cube" : renderer.mesh)),
                    i32(inspector_title_x + 20),
                    i32(mesh_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Material
                material_y := mesh_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Material: %s", 
                        renderer.material == "" ? "default" : renderer.material)),
                    i32(inspector_title_x + 20),
                    i32(material_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Visibility toggle - checkbox
                visible_y := material_y + 25
                raylib.DrawRectangleLines(
                    i32(inspector_title_x + 20),
                    i32(visible_y),
                    16,
                    16,
                    TEXT_COLOR
                )
                
                // Fill checkbox if enabled
                if renderer.visible {
                    raylib.DrawRectangle(
                        i32(inspector_title_x + 23),
                        i32(visible_y + 3),
                        10,
                        10,
                        TEXT_COLOR
                    )
                }
                
                draw_text(
                    "Visible",
                    i32(inspector_title_x + 45),
                    i32(visible_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
            }
        } else {
            // No entity selected
            draw_text(
                "No entity selected",
                i32(inspector_title_x + 20),
                i32(inspector_title_y + 50),
                FONT_SIZE,
                raylib.GRAY
            )
        }
        
        // Draw viewport info
        draw_text(
            strings.clone_to_cstring(fmt.tprintf("Viewport: %dx%d", 
                i32(editor_state.viewport_rect.width), 
                i32(editor_state.viewport_rect.height))),
            i32(editor_state.viewport_rect.x + 10),
            i32(editor_state.viewport_rect.y + 10),
            SMALL_FONT_SIZE,
            TEXT_COLOR
        )
        
        // Draw current tool info
        tool_names := map[Editor_Tool]string{
            .SELECT = "Select",
            .MOVE   = "Move (W)",
            .ROTATE = "Rotate (E)",
            .SCALE  = "Scale (R)",
        }
        
        draw_text(
            strings.clone_to_cstring(fmt.tprintf("Tool: %s", tool_names[editor_state.current_tool])),
            i32(editor_state.viewport_rect.x + 10),
            i32(editor_state.viewport_rect.y + 30),
            SMALL_FONT_SIZE,
            TEXT_COLOR
        )
        
        // Draw selected entity info
        if editor_state.selected_entity != 0 {
            entity_name := "Entity"
            
            if ecs_has_component(editor_state.selected_entity, .CAMERA) {
                camera := ecs_get_camera(editor_state.selected_entity)
                if camera != nil && camera.is_main {
                    entity_name = "Main Camera"
                } else {
                    entity_name = "Camera"
                }
            } else if ecs_has_component(editor_state.selected_entity, .LIGHT) {
                light := ecs_get_light(editor_state.selected_entity)
                if light != nil {
                    #partial switch light.light_type {
                        case .DIRECTIONAL: entity_name = "Directional Light"
                        case .POINT: entity_name = "Point Light"
                        case .SPOT: entity_name = "Spot Light"
                    }
                } else {
                    entity_name = "Light"
                }
            } else if ecs_has_component(editor_state.selected_entity, .RENDERER) {
                entity_name = "Mesh"
            }
            
            draw_text(
                strings.clone_to_cstring(fmt.tprintf("Selected: %s #%d", 
                    entity_name, editor_state.selected_entity)),
                i32(editor_state.viewport_rect.x + 10),
                i32(editor_state.viewport_rect.y + 50),
                SMALL_FONT_SIZE,
                TEXT_COLOR
            )
            
            // Display hotkeys reminder
            draw_text(
                "Press F1 to toggle editor, F5 to toggle play mode",
                i32(editor_state.viewport_rect.x + 10),
                i32(editor_state.viewport_rect.y + editor_state.viewport_rect.height - 30),
                SMALL_FONT_SIZE,
                raylib.GRAY
            )
        }
    }
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
    when ODIN_DEBUG {
        if !editor_state.initialized {
            return
        }
        
        log_info(.ENGINE, "Shutting down editor")
        
        // Unload font
        if editor_state.ui_font.texture.id > 0 {
            raylib.UnloadFont(editor_state.ui_font)
        }
        
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
        
        // Scene tree panel (left)
        editor_state.scene_tree_rect = raylib.Rectangle{
            x = 0,
            y = 0,
            width = PANEL_WIDTH,
            height = screen_height,
        }
        
        // Inspector panel (right)
        editor_state.inspector_rect = raylib.Rectangle{
            x = screen_width - PANEL_WIDTH,
            y = 0,
            width = PANEL_WIDTH,
            height = screen_height,
        }
        
        // Viewport (middle area)
        editor_state.viewport_rect = raylib.Rectangle{
            x = PANEL_WIDTH,
            y = 0,
            width = screen_width - (PANEL_WIDTH * 2),
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