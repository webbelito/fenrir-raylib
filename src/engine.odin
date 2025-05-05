#+feature dynamic-literals

package main

import "base:runtime"

import "core:log"
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

// Global engine running state
engine_is_running: bool = false
engine_is_playing: bool = false

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
	log_info(.ENGINE, "Initializing Fenrir Engine")

	// Initialize subsystems
	time_init()
	ecs_init()
	scene_init()

	// Initialize Raylib window
	raylib.InitWindow(
		config.window_width,
		config.window_height,
		strings.clone_to_cstring(config.app_name),
	)

	if config.vsync {
		// Set target FPS using our wrapper
		raylib.SetTargetFPS(config.target_fps)
	}

	if config.fullscreen {
		log_info(.ENGINE, "Toggling fullscreen mode")
		raylib.ToggleFullscreen()
	}

	if config.disable_escape_quit {
		log_info(.ENGINE, "Disabling escape key to quit")
		raylib.SetExitKey(raylib.KeyboardKey.F4)
	}

	// Initialize editor in debug builds
	when ODIN_DEBUG {
		editor_init()
	}

	// Create a default scene if none exists
	if !scene_is_loaded() {
		scene_new("Default Scene")
	}

	// Initialize asset manager
	asset_manager_init()

	engine_is_running = true
	log_info(.ENGINE, "Fenrir Engine initialized successfully")

	return true
}

// Start play mode (run the actual game)
engine_play :: proc() {
	if !engine_is_playing {
		log_info(.ENGINE, "Starting play mode")
		engine_is_playing = true

		// TODO: Additional play mode setup
	}
}

// Stop play mode (return to edit mode)
engine_stop :: proc() {
	if engine_is_playing {
		log_info(.ENGINE, "Stopping play mode")
		engine_is_playing = false

		// TODO: Additional play mode cleanup
	}
}

// Update the engine (one frame)
engine_update :: proc() -> bool {
	if raylib.WindowShouldClose() {
		log_debug(.ENGINE, "Window close requested")
		engine_is_running = false
	}

	// Update time
	time_update()

	// Update editor in debug mode
	when ODIN_DEBUG {
		// Toggle editor with F1 key
		if raylib.IsKeyPressed(.F1) {
			editor_toggle()
		}

		// Toggle play mode with F5 key
		if raylib.IsKeyPressed(.F5) {
			if engine_is_playing {
				engine_stop()
			} else {
				engine_play()
			}
		}

		editor_update()
	}

	// TODO: Update game systems (physics, AI, etc.)

	return engine_is_running
}

// Render the engine (one frame)
engine_render :: proc() -> bool {
	// Clear the screen
	raylib.ClearBackground(raylib.BLACK)

	// Begin drawing
	raylib.BeginDrawing()

	// Get the main camera
	camera_entity := scene_get_main_camera()
	if camera_entity != 0 {
		camera := ecs_get_camera(camera_entity)
		transform := ecs_get_transform(camera_entity)

		if camera != nil && transform != nil {
			// Set up camera
			camera_pos := raylib.Vector3 {
				transform.position[0],
				transform.position[1],
				transform.position[2],
			}
			camera_target := raylib.Vector3 {
				transform.position[0],
				transform.position[1],
				transform.position[2] + 1.0, // Look forward
			}
			camera_up := raylib.Vector3{0, 1, 0}

			// Begin 3D mode
			raylib.BeginMode3D(
				raylib.Camera3D {
					position = camera_pos,
					target = camera_target,
					up = camera_up,
					fovy = camera.fov,
					projection = .PERSPECTIVE,
				},
			)

			// Get all renderable entities
			renderer_entities := ecs_get_entities_with_component(.RENDERER)
			defer delete(renderer_entities)

			// Draw all renderable entities
			for entity in renderer_entities {
				renderer := ecs_get_renderer(entity)
				transform := ecs_get_transform(entity)

				if renderer != nil && transform != nil && renderer.visible {
					// Load and render the model
					model := load_model(renderer.mesh)
					if model != nil {
						// Set model texture if available
						if renderer.material != "" {
							texture := load_texture(renderer.material)
							if texture.id != 0 {
								model.texture = texture
							}
						}

						// Render the model
						render_model(model, transform)
					} else {
						// Fallback to cube if model loading fails
						position := raylib.Vector3 {
							transform.position[0],
							transform.position[1],
							transform.position[2],
						}
						size := raylib.Vector3 {
							transform.scale[0],
							transform.scale[1],
							transform.scale[2],
						}
						raylib.DrawCube(position, size.x, size.y, size.z, raylib.RED)
						raylib.DrawCubeWires(position, size.x, size.y, size.z, raylib.WHITE)
					}
				}
			}

			// End 3D mode
			raylib.EndMode3D()
		}
	}

	// Draw editor UI in debug mode
	when ODIN_DEBUG {
		editor_render()

		// Draw FPS counter
		raylib.DrawFPS(10, 10)

		// Draw play mode indicator
		if engine_is_playing {
			raylib.DrawText("PLAY MODE", raylib.GetScreenWidth() - 120, 10, 20, raylib.GREEN)
		}
	}

	// End drawing
	raylib.EndDrawing()

	return true
}

// Shutdown the engine
engine_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down Fenrir Engine")

	// Shutdown editor in debug mode
	when ODIN_DEBUG {
		editor_shutdown()
	}

	// Shutdown subsystems in reverse order
	scene_shutdown()
	ecs_shutdown()

	// Shutdown Raylib using our wrapper
	raylib.CloseWindow()
}

// Run the engine main loop
engine_run :: proc() {
	// Main game loop
	for engine_is_running {

		// Check if Escape key is pressed
		if raylib.IsKeyPressed(raylib.KeyboardKey.ESCAPE) {
			log_info(.ENGINE, "Escape key pressed, quitting")
			engine_is_running = false
		}

		if !engine_update() {
			break
		}
		engine_render()
	}
}

// Initialize the asset manager
asset_manager_init :: proc() {
	log_info(.ENGINE, "Initializing asset manager")
	asset_manager.models = make(map[string]Model)
	asset_manager.textures = make(map[string]raylib.Texture2D)
}

// Load a texture
load_texture :: proc(path: string) -> raylib.Texture2D {
	// Check if texture is already loaded
	if texture, ok := asset_manager.textures[path]; ok {
		return texture
	}

	// Load texture
	texture := raylib.LoadTexture(strings.clone_to_cstring(path))
	if texture.id == 0 {
		log_error(.ENGINE, "Failed to load texture: %s", path)
		return {}
	}

	// Store texture in asset manager
	asset_manager.textures[path] = texture
	return texture
}

// Load a model from a GLB file
load_model :: proc(path: string, config: ^Model_Config = nil) -> ^Model {
	// Use default config if none provided
	config := config if config != nil else &DEFAULT_MODEL_CONFIG

	// Check if model is already loaded
	if model, ok := &asset_manager.models[path]; ok {
		return model
	}

	log_info(.ENGINE, "Loading model: %s", path)

	// Load model
	model := new(Model)
	model.model = raylib.LoadModel(strings.clone_to_cstring(path))
	if model.model.meshCount == 0 {
		log_error(.ENGINE, "Failed to load model: %s (meshCount: %d)", path, model.model.meshCount)
		return nil
	}

	// Log detailed model info
	log_info(
		.ENGINE,
		"Model loaded: %s\n  Meshes: %d\n  Materials: %d\n  Bones: %d\n  BindPose: %v",
		path,
		model.model.meshCount,
		model.model.materialCount,
		model.model.boneCount,
		model.model.bindPose != nil,
	)

	// Setup materials
	setup_model_materials(model, config)

	// Store model in asset manager
	asset_manager.models[path] = model^

	return model
}

// Render a model
render_model :: proc(model: ^Model, transform: ^Transform) {
	if model == nil || transform == nil {
		return
	}

	// Set up model matrix
	model_matrix := raylib.Matrix(1)
	model_matrix =
		model_matrix *
		raylib.MatrixTranslate(transform.position.x, transform.position.y, transform.position.z)
	model_matrix =
		model_matrix *
		raylib.MatrixRotateXYZ(
			raylib.Vector3{transform.rotation.x, transform.rotation.y, transform.rotation.z},
		)
	model_matrix =
		model_matrix * raylib.MatrixScale(transform.scale.x, transform.scale.y, transform.scale.z)

	// Apply model matrix to the model
	model.model.transform = model_matrix

	// Draw model with its materials using Raylib's built-in function
	raylib.DrawModel(model.model, raylib.Vector3{0, 0, 0}, 1.0, raylib.WHITE)
}
