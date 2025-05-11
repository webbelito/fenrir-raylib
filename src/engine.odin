#+feature dynamic-literals

package main

import "base:runtime"

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import raylib "vendor:raylib"


// Engine Configuration
Engine_Config :: struct {
	app_name:            string,
	window_width:        i32,
	window_height:       i32,
	target_fps:          i32,
	vsync:               bool,
	fullscreen:          bool,
	disable_escape_quit: bool,
	default_context:     runtime.Context,
}

// Engine state
Engine_State :: struct {
	initialized:               bool,
	running:                   bool,
	playing:                   bool, // Add playing state
	time:                      Time_State,
	config:                    Engine_Config,
	editor_camera:             raylib.Camera3D, // Editor-specific camera
	needs_initial_dock_layout: bool, // Added flag for initial dock layout
}

// Global engine state
engine: Engine_State

// Mesh structure
Mesh :: struct {
	vertices:  [dynamic]raylib.Vector3,
	texcoords: [dynamic]raylib.Vector2,
	normals:   [dynamic]raylib.Vector3,
	indices:   [dynamic]i32,
}

// Material structure
Material :: struct {
	texture: raylib.Texture2D,
	shader:  raylib.Shader,
}

// Model structure
Model :: struct {
	model:   raylib.Model,
	texture: raylib.Texture2D,
}

// Asset manager
Asset_Manager :: struct {
	models:   map[string]Model,
	textures: map[string]raylib.Texture2D,
}

asset_manager: Asset_Manager

// Model loading configuration
Model_Config :: struct {
	texture_paths: [dynamic]string, // Ordered list of texture paths to try
	default_color: raylib.Color, // Default material color
	default_value: f32, // Default material value
}

// Default model configuration
DEFAULT_MODEL_CONFIG := Model_Config {
	texture_paths = {
		"assets/meshes/Textures/colormap.png", // GLB's expected path
		"assets/textures/colormap.png", // Fallback path
	},
	default_color = raylib.WHITE,
	default_value = 1.0,
}

// Create a default material with the given texture
create_default_material :: proc(
	texture: raylib.Texture2D,
	config: ^Model_Config,
) -> ^raylib.Material {
	material := new(raylib.Material)
	material^ = raylib.Material{}
	material.maps[0].texture = texture
	material.maps[0].color = config.default_color
	material.maps[0].value = config.default_value
	return material
}

// Try to load a texture from multiple possible paths
load_texture_from_paths :: proc(paths: []string) -> raylib.Texture2D {
	for path in paths {
		texture := load_texture(path)
		if texture.id != 0 {
			log_info(.ENGINE, "Loaded texture from: %s", path)
			return texture
		}
		log_warning(.ENGINE, "Failed to load texture from: %s", path)
	}
	return {}
}

// Setup materials for a model
setup_model_materials :: proc(model: ^Model, config: ^Model_Config) {
	if model.model.materialCount == 0 {
		log_warning(.ENGINE, "Model has no materials, creating default material")
		texture := load_texture_from_paths(config.texture_paths[:])
		if texture.id == 0 {
			log_error(.ENGINE, "Failed to load default texture")
			return
		}
		model.model.materials = create_default_material(texture, config)
		model.model.materialCount = 1
		return
	}

	// Setup existing materials
	for i in 0 ..< model.model.materialCount {
		material := &model.model.materials[i]

		if material.maps[0].texture.id == 0 {
			texture := load_texture_from_paths(config.texture_paths[:])
			if texture.id != 0 {
				material.maps[0].texture = texture
				material.maps[0].color = config.default_color
				material.maps[0].value = config.default_value
				log_info(.ENGINE, "Applied texture to material %d", i)
			} else {
				log_error(.ENGINE, "Failed to load texture for material %d", i)
			}
		} else {
			log_info(.ENGINE, "Material %d already has a texture", i)
		}
	}
}

// Initialize the engine
engine_init :: proc(config: Engine_Config) -> bool {
	if engine.initialized {
		log_warning(.ENGINE, "Engine already initialized")
		return false
	}

	log_info(.ENGINE, "Initializing engine")

	// Initialize entity manager
	entity_manager_init()

	// Initialize command manager
	command_manager_init()

	// Initialize component system
	component_system_init()

	// Initialize asset manager
	asset_manager_init()

	// Initialize scene manager
	scene_manager_init()

	// Create a new empty scene
	if !scene_manager_new("Untitled") {
		log_error(.ENGINE, "Failed to create initial scene")
		return false
	}

	// Initialize engine state
	engine.initialized = true
	engine.running = true
	engine.playing = false
	engine.config = config
	engine.needs_initial_dock_layout = true // Initialize the flag

	// Initialize editor camera
	engine.editor_camera = raylib.Camera3D {
		position   = {0, 5, -10},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	log_info(.ENGINE, "Engine initialized successfully")
	return true
}

// Shutdown the engine
engine_shutdown :: proc() {
	if !engine.initialized {
		log_warning(.ENGINE, "Engine not initialized")
		return
	}

	log_info(.ENGINE, "Shutting down engine")

	// Shutdown entity manager
	entity_manager_shutdown()

	// Shutdown command manager
	command_manager_shutdown()

	// Shutdown component system
	component_system_shutdown()

	// Shutdown asset manager
	asset_manager_shutdown()

	// Shutdown scene manager
	scene_manager_shutdown()

	engine.initialized = false
	engine.running = false
	engine.playing = false

	log_info(.ENGINE, "Engine shutdown complete")
}

// Update the engine
engine_update :: proc() {
	if !engine.initialized {
		return
	}

	// Update time first
	time_update()

	// Begin ImGui frame (handles input, DeltaTime, etc.)
	imgui_begin_frame()

	// Handle camera movement based on mode
	if !imgui.IsAnyItemActive() {
		if editor.initialized {
			// Editor camera controls
			if raylib.IsKeyDown(.W) {
				engine.editor_camera.position += raylib.Vector3{0, 0, -0.1}
				engine.editor_camera.target += raylib.Vector3{0, 0, -0.1}
			}
			if raylib.IsKeyDown(.S) {
				engine.editor_camera.position += raylib.Vector3{0, 0, 0.1}
				engine.editor_camera.target += raylib.Vector3{0, 0, 0.1}
			}
			if raylib.IsKeyDown(.A) {
				engine.editor_camera.position += raylib.Vector3{-0.1, 0, 0}
				engine.editor_camera.target += raylib.Vector3{-0.1, 0, 0}
			}
			if raylib.IsKeyDown(.D) {
				engine.editor_camera.position += raylib.Vector3{0.1, 0, 0}
				engine.editor_camera.target += raylib.Vector3{0.1, 0, 0}
			}
		} else if engine.playing {
			// Game camera controls (example)
		}
	}

	// Update scene logic
	if scene_manager_is_loaded() {
		scene_manager_update()
	}

	// Update editor logic (panel states, etc., but not their ImGui rendering definitions yet)
	if editor.initialized {
		editor_update()
	}
}

// Render the engine
engine_render :: proc() {
	if !engine.initialized {
		return
	}

	raylib.BeginDrawing() // Main window drawing context
	{
		raylib.ClearBackground(raylib.BLACK)

		// Create a full-screen window to host the dockspace and main menu
		main_viewport_imgui := imgui.GetMainViewport()
		imgui.SetNextWindowPos(main_viewport_imgui.WorkPos)
		imgui.SetNextWindowSize(main_viewport_imgui.WorkSize)
		imgui.SetNextWindowViewport(main_viewport_imgui.ID_)

		dockspace_host_window_flags := imgui.WindowFlags {
			.NoDocking,
			.NoTitleBar,
			.NoCollapse,
			.NoResize,
			.NoMove,
			.NoBringToFrontOnFocus,
			.NoNavFocus,
			.NoBackground,
			.MenuBar,
		}

		imgui.PushStyleVar(.WindowRounding, 0.0)
		imgui.PushStyleVar(.WindowBorderSize, 0.0)
		// Skipping PushStyleVar for .WindowPadding to avoid linter issue.
		// This means the DockSpace Host window will have default padding.

		imgui.Begin("DockSpace Host", nil, dockspace_host_window_flags)
		{
			// We pushed 2 style vars, so pop 2.
			imgui.PopStyleVar(2)

			// Submit the DockSpace using positional arguments
			dockspace_id_val := imgui.GetID("MainDockspace")

			// Setup initial dock layout if needed
			if engine.needs_initial_dock_layout {
				main_viewport_size := main_viewport_imgui.WorkSize // Use WorkSize for usable area

				imgui.DockBuilderRemoveNode(dockspace_id_val)
				imgui.DockBuilderAddNode(dockspace_id_val, {})
				imgui.DockBuilderSetNodeSize(dockspace_id_val, main_viewport_size)

				dock_id_scene_tree: imgui.ID
				dock_id_center_right: imgui.ID
				// Split root dockspace: left part for scene tree, remaining is center_right
				// The returned ID from DockBuilderSplitNode is the ID of the *parent* node that was split.
				// The new child nodes are in the out parameters.
				_ = imgui.DockBuilderSplitNode(
					dockspace_id_val,
					imgui.Dir.Left,
					0.20,
					&dock_id_scene_tree,
					&dock_id_center_right,
				)

				dock_id_inspector: imgui.ID
				dock_id_viewport: imgui.ID
				// Split center_right: right part for inspector, remaining is viewport (final center)
				_ = imgui.DockBuilderSplitNode(
					dock_id_center_right,
					imgui.Dir.Right,
					0.25,
					&dock_id_inspector,
					&dock_id_viewport,
				)

				imgui.DockBuilderDockWindow("Scene Tree", dock_id_scene_tree)
				imgui.DockBuilderDockWindow("Inspector", dock_id_inspector)
				imgui.DockBuilderDockWindow("Viewport", dock_id_viewport)

				imgui.DockBuilderFinish(dockspace_id_val)
				engine.needs_initial_dock_layout = false
			}

			dock_size_val := imgui.Vec2{0.0, 0.0}
			dock_node_flags_val := imgui.DockNodeFlags{.PassthruCentralNode}
			imgui.DockSpace(dockspace_id_val, dock_size_val, dock_node_flags_val)

			// Call the main editor rendering function
			if editor.initialized {
				editor_render()
			}
		}
		imgui.End() // End DockSpace Host window

		// Draw the 3D scene
		if editor.viewport_open &&
		   viewport_state.rect_width > 0 &&
		   viewport_state.rect_height > 0 {
			editor_viewport_draw_3d_scene(
				viewport_state.rect_x,
				viewport_state.rect_y,
				viewport_state.rect_width,
				viewport_state.rect_height,
			)
		}

		// ImGui rendering is finalized here
		imgui_end_frame()
	}
	raylib.EndDrawing()
}

// Check if the engine should continue running
engine_should_run :: proc() -> bool {
	return engine.running && !raylib.WindowShouldClose()
}

// Render a model
render_model :: proc(
	model: ^raylib.Model,
	position: raylib.Vector3,
	rotation: raylib.Vector3,
	scale: raylib.Vector3,
) {
	if model == nil {
		return
	}

	// Set up model matrix
	model_matrix :=
		raylib.MatrixRotateXYZ(rotation) *
		raylib.MatrixScale(scale.x, scale.y, scale.z) *
		raylib.MatrixTranslate(position.x, position.y, position.z)

	// Apply model matrix to the model
	model.transform = model_matrix

	// Draw model
	raylib.DrawModel(model^, position, 1.0, raylib.WHITE)
}

// Run the engine main loop
engine_run :: proc() {
	// Main game loop
	for engine_should_run() {
		engine_update()
		engine_render()
	}
}
