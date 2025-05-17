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

// Script component definition
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
