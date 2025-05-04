#+feature dynamic-literals
package main

import "core:strings"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"
import "core:os"

// Constants for editor layout
PANEL_WIDTH :: 250
SCENE_TREE_HEIGHT :: 0.5 // percentage of screen height
FONT_SIZE :: 18
SMALL_FONT_SIZE :: 16

// Editor theme colors
PANEL_COLOR :: raylib.DARKGRAY
PANEL_BORDER_COLOR :: raylib.BLACK
TITLE_COLOR :: raylib.WHITE
SELECTED_COLOR :: raylib.BLUE
TEXT_COLOR :: raylib.WHITE
HIGHLIGHTED_TEXT_COLOR :: raylib.YELLOW

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
    } else {
        return false
    }
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
        
        // Draw panel titles
        title_x := editor_state.scene_tree_rect.x + 10
        title_y := editor_state.scene_tree_rect.y + 10
        draw_text("Scene Tree", i32(title_x), i32(title_y), FONT_SIZE, TITLE_COLOR)
        
        inspector_title_x := editor_state.inspector_rect.x + 10
        inspector_title_y := editor_state.inspector_rect.y + 10
        draw_text("Inspector", i32(inspector_title_x), i32(inspector_title_y), FONT_SIZE, TITLE_COLOR)
        
        // Draw viewport border
        raylib.DrawRectangleLinesEx(editor_state.viewport_rect, 2, PANEL_BORDER_COLOR)
        
        // Draw scene tree with actual entities
        if scene_is_loaded() {
            scene_entities := scene_get_entities()
            defer delete(scene_entities)
            
            start_y := title_y + 35
            
            // Show scene name
            scene_name_y := start_y - 25
            draw_text(
                strings.clone_to_cstring(fmt.tprintf("Scene: %s%s", 
                    current_scene.name, 
                    scene_is_dirty() ? "*" : "")),
                i32(title_x),
                i32(scene_name_y),
                SMALL_FONT_SIZE,
                TEXT_COLOR
            )
            
            // Draw each entity in the scene
            for i := 0; i < len(scene_entities); i += 1 {
                entity := scene_entities[i]
                text_y := start_y + f32(i * 28) - editor_state.scene_tree_scroll
                
                // Skip if outside visible area
                if text_y < title_y || text_y > editor_state.scene_tree_rect.y + editor_state.scene_tree_rect.height {
                    continue
                }
                
                text_color := TEXT_COLOR
                
                // Highlight selected entity
                if entity == editor_state.selected_entity {
                    node_rect := raylib.Rectangle{
                        x = editor_state.scene_tree_rect.x + 5,
                        y = text_y - 2,
                        width = editor_state.scene_tree_rect.width - 10,
                        height = 28,
                    }
                    raylib.DrawRectangleRec(node_rect, SELECTED_COLOR)
                    text_color = HIGHLIGHTED_TEXT_COLOR
                }
                
                // Get entity name or ID if no name
                entity_name := fmt.tprintf("Entity %d", entity)
                
                // Determine entity type based on components
                icon_x := editor_state.scene_tree_rect.x + 15
                icon_y := text_y + 10
                icon_color := raylib.LIGHTGRAY
                
                if ecs_has_component(entity, .CAMERA) {
                    icon_color = raylib.SKYBLUE
                    camera := ecs_get_camera(entity)
                    if camera != nil && camera.is_main {
                        entity_name = "Main Camera"
                    } else {
                        entity_name = "Camera"
                    }
                } else if ecs_has_component(entity, .LIGHT) {
                    icon_color = raylib.YELLOW
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
                    icon_color = raylib.RED
                    entity_name = "Mesh"
                } else if i == 0 { // Assume first entity might be root
                    icon_color = raylib.GREEN
                    entity_name = "Root"
                }
                
                raylib.DrawCircle(i32(icon_x), i32(icon_y), 4, icon_color)
                
                // Draw entity name
                draw_text(
                    strings.clone_to_cstring(entity_name),
                    i32(icon_x + 15),
                    i32(text_y),
                    FONT_SIZE,
                    text_color
                )
            }
        } else {
            // No scene loaded
            draw_text(
                "No scene loaded",
                i32(title_x + 20),
                i32(title_y + 50),
                FONT_SIZE,
                raylib.GRAY
            )
        }
        
        // Draw inspector contents if an entity is selected
        if editor_state.selected_entity != 0 {
            content_y := inspector_title_y + 35
            
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
            
            // Draw name field with outline
            raylib.DrawRectangleLines(
                i32(inspector_title_x), 
                i32(content_y),
                i32(editor_state.inspector_rect.width - 20),
                30,
                raylib.DARKGRAY
            )
            
            draw_text(
                strings.clone_to_cstring(fmt.tprintf("Name: %s #%d", entity_name, editor_state.selected_entity)),
                i32(inspector_title_x + 10), 
                i32(content_y + 5), 
                SMALL_FONT_SIZE, 
                TEXT_COLOR
            )
            
            // Transform section if entity has transform
            if transform := ecs_get_transform(editor_state.selected_entity); transform != nil {
                transform_y := content_y + 40
                
                // Header with box
                raylib.DrawRectangleLines(
                    i32(inspector_title_x),
                    i32(transform_y),
                    i32(editor_state.inspector_rect.width - 20),
                    25,
                    raylib.DARKGRAY
                )
                
                draw_text(
                    "Transform",
                    i32(inspector_title_x + 10),
                    i32(transform_y + 3),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Position
                position_y := transform_y + 35
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Position: %.1f, %.1f, %.1f", 
                        transform.position[0], transform.position[1], transform.position[2])),
                    i32(inspector_title_x + 20),
                    i32(position_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Rotation
                rotation_y := position_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Rotation: %.1f, %.1f, %.1f",
                        transform.rotation[0], transform.rotation[1], transform.rotation[2])),
                    i32(inspector_title_x + 20),
                    i32(rotation_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                // Scale
                scale_y := rotation_y + 25
                draw_text(
                    strings.clone_to_cstring(fmt.tprintf("Scale: %.1f, %.1f, %.1f",
                        transform.scale[0], transform.scale[1], transform.scale[2])),
                    i32(inspector_title_x + 20),
                    i32(scale_y),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
                )
                
                content_y = scale_y + 35
            }
            
            // Camera component
            if camera := ecs_get_camera(editor_state.selected_entity); camera != nil {
                camera_y := content_y
                
                // Header with box
                raylib.DrawRectangleLines(
                    i32(inspector_title_x),
                    i32(camera_y),
                    i32(editor_state.inspector_rect.width - 20),
                    25,
                    raylib.DARKGRAY
                )
                
                draw_text(
                    "Camera",
                    i32(inspector_title_x + 10),
                    i32(camera_y + 3),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
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
                
                // Header with box
                raylib.DrawRectangleLines(
                    i32(inspector_title_x),
                    i32(light_y),
                    i32(editor_state.inspector_rect.width - 20),
                    25,
                    raylib.DARKGRAY
                )
                
                draw_text(
                    "Light",
                    i32(inspector_title_x + 10),
                    i32(light_y + 3),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
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
                
                // Header with box
                raylib.DrawRectangleLines(
                    i32(inspector_title_x),
                    i32(renderer_y),
                    i32(editor_state.inspector_rect.width - 20),
                    25,
                    raylib.DARKGRAY
                )
                
                draw_text(
                    "Renderer",
                    i32(inspector_title_x + 10),
                    i32(renderer_y + 3),
                    SMALL_FONT_SIZE,
                    TEXT_COLOR
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