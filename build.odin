#+feature dynamic-literals
package build

import "core:strings"
import "core:slice"
import "core:path/filepath"
import os "core:os/os2"
import "core:fmt"
import "core:io"
import logging "src"

// Project configuration
PROJECT_ROOT :: #config(PROJECT_ROOT, ".")

// Paths configuration
ODIN_VENDOR_PATH :: #config(ODIN_VENDOR_PATH, "C:/Users/antwah/odin/vendor")
ODIN_SHARED_PATH :: #config(ODIN_SHARED_PATH, "C:/Users/antwah/odin/shared")
RAYLIB_DLL_PATH :: #config(RAYLIB_DLL_PATH, "C:/Users/antwah/odin/vendor/raylib/windows")
SHADERCROSS_PATH :: #config(SHADERCROSS_PATH, "C:/Users/antwah/shadercross")

// Build settings
DEBUG_EXE_NAME :: "fenrir_debug.exe"
RELEASE_EXE_NAME :: "fenrir.exe"

// External dependencies
IMGUI_REPO_URL :: "https://gitlab.com/nadako/odin-imgui/-/tree/sdlgpu3?ref_type=heads"
IMGUI_CLONE_CMD :: "git clone https://gitlab.com/nadako/odin-imgui.git -b sdlgpu3 imgui"
SHADERCROSS_REPO_URL :: "https://github.com/libsdl-org/SDL_shadercross"
SHADERCROSS_ACTIONS_URL :: "https://github.com/libsdl-org/SDL_shadercross/actions"

// Shader constants
SHADER_TYPE_VERTEX :: "vertex"
SHADER_TYPE_FRAGMENT :: "fragment"
SHADER_FORMAT_SPIRV :: "SPIRV"
SHADER_FORMAT_METAL :: "MSL"
SHADER_FORMAT_DXIL :: "DXIL"

validate_config :: proc() -> bool {
	if !os.exists(PROJECT_ROOT) {
		logging.log_build_error("Project root '%s' does not exist. Please update the build.odin file.", PROJECT_ROOT)
		return false
	}
	
	raylib_path := filepath.join({RAYLIB_DLL_PATH, "raylib.dll"})
	if !os.exists(raylib_path) {
		logging.log_build_error("raylib.dll not found at '%s'. Please update the RAYLIB_DLL_PATH in build.odin.", raylib_path)
		return false
	}

	raygui_path := filepath.join({RAYLIB_DLL_PATH, "raygui.dll"})
	if !os.exists(raygui_path) {
		logging.log_build_error("raygui.dll not found at '%s'. Please update the RAYLIB_DLL_PATH in build.odin.", raygui_path)
		return false
	}
	
	imgui_path := filepath.join({ODIN_SHARED_PATH, "imgui"})
	if !os.exists(imgui_path) {
		logging.log_build_error("ImGui not found at '%s'.", imgui_path)
		logging.log_build_error("Please install ImGui using the following command:")
		logging.log_build_error("cd %s && %s", ODIN_SHARED_PATH, IMGUI_CLONE_CMD)
		logging.log_build_error("Repository URL: %s", IMGUI_REPO_URL)
		return false
	}
	
	return true
}

build_debug :: proc() -> (success: bool) {
	project_root := PROJECT_ROOT
	
	// Create directories
	logging.log_build_info("Creating directory structure...")
	os.make_directory_all(filepath.join({project_root, "assets/meshes"}))
	os.make_directory_all(filepath.join({project_root, "assets/scenes"}))
	os.make_directory_all(filepath.join({project_root, "assets/shaders/src/game"}))
	os.make_directory_all(filepath.join({project_root, "assets/shaders/src/editor"}))
	os.make_directory_all(filepath.join({project_root, "assets/shaders/bin/game"}))
	os.make_directory_all(filepath.join({project_root, "assets/shaders/bin/editor"}))
	os.make_directory_all(filepath.join({project_root, "assets/textures"}))
	os.make_directory_all(filepath.join({project_root, "bin/release"}))
	
	// Build in debug mode
	output_path := filepath.join({project_root, DEBUG_EXE_NAME})
	
	// Build with debug flag - this automatically defines ODIN_DEBUG
	build_flags := []string{"-debug"}
	
	// Source directory
	src_dir := filepath.join({project_root, "src"})
	
	logging.log_build_info("Building project in debug mode with editor...")
	logging.log_build_info("Source directory: %s", src_dir)
	logging.log_build_info("Output path: %s", output_path)
	
	// Create full command with all build flags
	command := make([dynamic]string)
	append(&command, "odin")
	append(&command, "build")
	append(&command, src_dir)
	for flag in build_flags {
		append(&command, flag)
	}
	append(&command, fmt.tprintf("-out:%s", output_path))
	
	// Run the build command
	build_process, process_err := os.process_start({
		command = slice.clone(command[:]), // Convert dynamic array to slice
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	
	if process_err != nil {
		logging.log_build_error("Failed to start build process: %v", process_err)
		return false
	}
	
	build_state, wait_err := os.process_wait(build_process)
	if wait_err != nil {
		logging.log_build_error("Failed to wait for build process: %v", wait_err)
		return false
	}
	
	close_err := os.process_close(build_process)
	if close_err != nil {
		logging.log_build_error("Failed to close build process: %v", close_err)
		return false
	}
	
	if build_state.exit_code != 0 {
		logging.log_build_error("Build failed")
		return false
	}
	
	// Copy raylib.dll
	logging.log_build_info("Copying raylib.dll...")
	raylib_path := filepath.join({RAYLIB_DLL_PATH, "raylib.dll"})
	dest_path := filepath.join({project_root, "raylib.dll"})
	logging.log_build_info("Raylib source path: %s", raylib_path)
	logging.log_build_info("Raylib destination path: %s", dest_path)
	
	if !os.exists(raylib_path) {
		logging.log_build_error("raylib.dll not found at '%s'", raylib_path)
		return false
	} else {
		data, read_err := os.read_entire_file_from_path(raylib_path, context.allocator)
		defer delete(data)
		if read_err != nil {
			logging.log_build_error("Failed to read raylib.dll: %v", read_err)
			return false
		} else {
			write_err := os.write_entire_file(dest_path, data)
			if write_err != nil {
				logging.log_build_error("Failed to write raylib.dll: %v", write_err)
				return false
			} else {
				logging.log_build_info("Successfully copied raylib.dll")
			}
		}
	}
	
	// Copy raygui.dll if it exists
	raygui_path := filepath.join({RAYLIB_DLL_PATH, "raygui.dll"})
	if os.exists(raygui_path) {
		logging.log_build_info("Copying raygui.dll...")
		raygui_dest_path := filepath.join({project_root, "raygui.dll"})
		logging.log_build_info("Raygui source path: %s", raygui_path)
		logging.log_build_info("Raygui destination path: %s", raygui_dest_path)
		
		data, read_err := os.read_entire_file_from_path(raygui_path, context.allocator)
		defer delete(data)
		if read_err != nil {
			logging.log_build_error("Failed to read raygui.dll: %v", read_err)
			return false
		} else {
			write_err := os.write_entire_file(raygui_dest_path, data)
			if write_err != nil {
				logging.log_build_error("Failed to write raygui.dll: %v", write_err)
				return false
			} else {
				logging.log_build_info("Successfully copied raygui.dll")
			}
		}
	}
	
	logging.log_build_info("Debug build complete!")
	return true
}

build_release :: proc() -> (success: bool) {
	project_root := PROJECT_ROOT
	
	// Create directories
	logging.log_build_info("Creating directory structure...")
	os.make_directory_all(filepath.join({project_root, "assets/meshes"}))
	os.make_directory_all(filepath.join({project_root, "assets/scenes"}))
	os.make_directory_all(filepath.join({project_root, "assets/shaders/src/game"}))
	// No editor folder needed for release
	os.make_directory_all(filepath.join({project_root, "assets/shaders/bin/game"}))
	// No editor shader output needed for release
	os.make_directory_all(filepath.join({project_root, "assets/textures"}))
	os.make_directory_all(filepath.join({project_root, "src/game"}))
	os.make_directory_all(filepath.join({project_root, "src/editor"}))  // Still needed for compilation
	os.make_directory_all(filepath.join({project_root, "bin/release"}))
	
	// Build in release mode
	release_dir := filepath.join({project_root, "bin/release"})
	output_path := filepath.join({release_dir, RELEASE_EXE_NAME})
	
	// Build with optimization flag, but no debug flag and no ODIN_DEBUG define
	build_flags := []string{"-o:speed"}
	
	src_dir := filepath.join({project_root, "src"})
	
	logging.log_build_info("Building project in release mode (no editor)...")
	logging.log_build_info("Source directory: %s", src_dir)
	logging.log_build_info("Output path: %s", output_path)
	
	// Create full command with all build flags
	command := make([dynamic]string)
	append(&command, "odin")
	append(&command, "build")
	append(&command, src_dir)
	for flag in build_flags {
		append(&command, flag)
	}
	append(&command, fmt.tprintf("-out:%s", output_path))
	
	// Run the build command
	build_process, process_err := os.process_start({
		command = slice.clone(command[:]), // Convert dynamic array to slice
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	
	if process_err != nil {
		logging.log_build_error("Failed to start build process: %v", process_err)
		return false
	}
	
	build_state, wait_err := os.process_wait(build_process)
	if wait_err != nil {
		logging.log_build_error("Failed to wait for build process: %v", wait_err)
		return false
	}
	
	close_err := os.process_close(build_process)
	if close_err != nil {
		logging.log_build_error("Failed to close build process: %v", close_err)
		return false
	}
	
	if build_state.exit_code != 0 {
		logging.log_build_error("Build failed")
		return false
	}
	
	// Copy raylib.dll
	logging.log_build_info("Copying raylib.dll...")
	raylib_path := filepath.join({RAYLIB_DLL_PATH, "raylib.dll"})
	dest_path := filepath.join({release_dir, "raylib.dll"})
	logging.log_build_info("Raylib source path: %s", raylib_path)
	logging.log_build_info("Raylib destination path: %s", dest_path)
	
	if !os.exists(raylib_path) {
		logging.log_build_error("raylib.dll not found at '%s'", raylib_path)
		return false
	} else {
		data, read_err := os.read_entire_file_from_path(raylib_path, context.allocator)
		defer delete(data)
		if read_err != nil {
			logging.log_build_error("Failed to read raylib.dll: %v", read_err)
			return false
		} else {
			write_err := os.write_entire_file(dest_path, data)
			if write_err != nil {
				logging.log_build_error("Failed to write raylib.dll: %v", write_err)
				return false
			} else {
				logging.log_build_info("Successfully copied raylib.dll")
			}
		}
	}
	
	// Copy raygui.dll if it exists
	raygui_path := filepath.join({RAYLIB_DLL_PATH, "raygui.dll"})
	if os.exists(raygui_path) {
		logging.log_build_info("Copying raygui.dll...")
		raygui_dest_path := filepath.join({release_dir, "raygui.dll"})
		logging.log_build_info("Raygui source path: %s", raygui_path)
		logging.log_build_info("Raygui destination path: %s", raygui_dest_path)
		
		data, read_err := os.read_entire_file_from_path(raygui_path, context.allocator)
		defer delete(data)
		if read_err != nil {
			logging.log_build_error("Failed to read raygui.dll: %v", read_err)
			return false
		} else {
			write_err := os.write_entire_file(raygui_dest_path, data)
			if write_err != nil {
				logging.log_build_error("Failed to write raygui.dll: %v", write_err)
				return false
			} else {
				logging.log_build_info("Successfully copied raygui.dll")
			}
		}
	}
	
	// Copy assets directory (no editor assets in release)
	assets_dir := filepath.join({project_root, "assets"})
	if os.exists(assets_dir) && os.is_dir(assets_dir) {
		logging.log_build_info("Copying game assets...")
		dest_assets_dir := filepath.join({release_dir, "assets"})
		
		// Create the destination assets directory
		if !os.exists(dest_assets_dir) {
			os.make_directory(dest_assets_dir)
		}
		
		// Copy all assets except editor content
		os.make_directory_all(filepath.join({dest_assets_dir, "meshes"}))
		os.make_directory_all(filepath.join({dest_assets_dir, "scenes"}))
		os.make_directory_all(filepath.join({dest_assets_dir, "shaders/bin/game"}))
		os.make_directory_all(filepath.join({dest_assets_dir, "textures"}))
		
		// Copy meshes directory
		meshes_src := filepath.join({assets_dir, "meshes"})
		meshes_dst := filepath.join({dest_assets_dir, "meshes"})
		copy_directory(meshes_src, meshes_dst)
		
		// Copy scenes directory
		scenes_src := filepath.join({assets_dir, "scenes"})
		scenes_dst := filepath.join({dest_assets_dir, "scenes"})
		copy_directory(scenes_src, scenes_dst)
		
		// Copy game shaders bin directory
		shaders_src := filepath.join({assets_dir, "shaders/bin/game"})
		shaders_dst := filepath.join({dest_assets_dir, "shaders/bin/game"})
		copy_directory(shaders_src, shaders_dst)
		
		// Copy textures directory
		textures_src := filepath.join({assets_dir, "textures"})
		textures_dst := filepath.join({dest_assets_dir, "textures"})
		copy_directory(textures_src, textures_dst)
		
		logging.log_build_info("Assets copied successfully")
	} else {
		logging.log_build_warn("Assets directory not found at '%s', skipping copy", assets_dir)
	}
	
	// Create README.txt
	logging.log_build_info("Creating README.txt...")
	readme := `Fenrir Raylib Game Engine
=======================

A simple game engine built with Odin and Raylib.

How to Run:
-----------
Simply double-click on Fenrir.exe to run the application.

Controls:
---------
(Add your controls here)

Credits:
--------
Created with Odin (https://odin-lang.org/) and Raylib (https://www.raylib.com/)
`
	
	readme_path := filepath.join({release_dir, "README.txt"})
	write_err := os.write_entire_file(readme_path, transmute([]byte)readme)
	if write_err != nil {
		logging.log_build_error("Failed to create README.txt: %v", write_err)
		return false
	}
	
	logging.log_build_info("Release build complete!")
	logging.log_build_info("The release package is ready in the 'bin/release' directory.")
	logging.log_build_info("You can copy this folder and run it from anywhere.")
	return true
}

// Helper to copy a directory
copy_directory :: proc(src, dst: string) {
	if !os.exists(src) {
		logging.log_build_warn("Source directory '%s' does not exist", src)
		return
	}
	
	if !os.exists(dst) {
		os.make_directory_all(dst)
	}
	
	// Use robocopy on Windows for efficient directory copying
	copy_cmd := []string{
		"robocopy", 
		src, 
		dst, 
		"/E", // Copy subdirectories including empty ones
		"/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS" // Reduce output verbosity
	}
	
	logging.log_build_info("Copying from %s to %s", src, dst)
	
	process, err := os.process_start({
		command = copy_cmd,
		stdin = os.stdin,
		stdout = os.stdout,
		stderr = os.stderr,
	})
	
	if err != nil {
		logging.log_build_error("Failed to start copy process: %v", err)
		return
	}
	
	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		logging.log_build_error("Failed to wait for copy process: %v", wait_err)
	}
	
	close_err := os.process_close(process)
	if close_err != nil {
		logging.log_build_error("Failed to close copy process: %v", close_err)
	}
	
	// Robocopy return codes: 0-7 are successful, >8 indicates errors
	if state.exit_code > 8 {
		logging.log_build_error("Copy failed with exit code: %d", state.exit_code)
	}
}

main :: proc() {
	// Setup logging
	logging.log_init()
	defer logging.log_shutdown()
	
	// Check platform
	if ODIN_OS != .Windows {
		logging.log_build_error("This build script only supports Windows.")
		os.exit(1)
	}
	
	// Validate configuration
	logging.log_build_info("Validating configuration...")
	if !validate_config() {
		logging.log_build_error("Configuration validation failed. Please check the build.odin file.")
		os.exit(1)
	}
	
	// Default to debug build
	build_type := "debug"
	
	// Check command line args
	for i := 1; i < len(os.args); i += 1 {
		if os.args[i] == "release" {
			build_type = "release"
			break
		}
	}
	
	logging.log_build_info("Build type: %s", build_type)
	
	// Run the appropriate build
	build_success := false
	if build_type == "debug" {
		build_success = build_debug()
	} else {
		build_success = build_release()
	}
	
	// Exit with appropriate status code
	if !build_success {
		logging.log_build_error("Build process failed. See errors above.")
		os.exit(1)
	}
	
	logging.log_build_info("Build process completed successfully.")
} 