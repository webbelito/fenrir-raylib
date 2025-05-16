package main

import raylib "vendor:raylib"

// Component types for type identification
Component_Type :: enum {
	TRANSFORM,
	RENDERER,
	CAMERA,
	LIGHT,
	SCRIPT,
	COLLIDER,
	RIGIDBODY,
	AUDIO_SOURCE,
}

// Transform component - just position, rotation, scale data
Transform :: struct {
	position:     raylib.Vector3,
	rotation:     raylib.Vector3, // In degrees
	scale:        raylib.Vector3,
	local_matrix: raylib.Matrix, // Local transform matrix
	world_matrix: raylib.Matrix, // World transform matrix
	dirty:        bool, // Flag to indicate if transform needs updating
}

// Renderer component - just rendering data
Renderer :: struct {
	visible:       bool,
	model_type:    Model_Type,
	mesh_path:     string,
	material_path: string,
}

// Model types
Model_Type :: enum {
	CUBE,
	SPHERE,
	PLANE,
	AMBULANCE,
	CUSTOM,
}

// Camera component - just camera data
Camera :: struct {
	fov:     f32,
	near:    f32,
	far:     f32,
	is_main: bool,
}

// Light component - just light data
Light :: struct {
	light_type: Light_Type,
	color:      raylib.Vector3,
	intensity:  f32,
	range:      f32,
	spot_angle: f32,
}

// Light types
Light_Type :: enum {
	DIRECTIONAL,
	POINT,
	SPOT,
}

// Script component - just script data
Script :: struct {
	script_name: string,
}

// Component data for serialization
Component_Data :: union {
	Transform,
	Renderer,
	Camera,
	Light,
	Script,
}
