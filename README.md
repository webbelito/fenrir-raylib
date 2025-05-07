# Fenrir Engine

A 3D game engine built with Odin and Raylib, featuring a custom ECS (Entity Component System) architecture.

## Features

- **ECS Architecture**: Custom Entity Component System for efficient game object management
- **3D Rendering**: Powered by Raylib for high-performance 3D graphics
- **Scene Management**: Save and load scenes in JSON format
- **Editor Interface**: Built-in editor with ImGui integration
  - Scene Tree view
  - Inspector panel
  - File browser for scene management
  - Entity creation and manipulation
  - Component editing

## Project Structure

```
fenrir-raylib/
├── src/
│   ├── editor.odin        # Editor UI and scene management
│   ├── engine.odin        # Core engine systems
│   ├── scene.odin         # Scene management and serialization
│   ├── component_manager.odin  # Component system management
│   ├── entity_manager.odin     # Entity system management
│   ├── component_*.odin   # Individual component implementations
│   ├── main.odin          # Entry point
│   ├── log.odin           # Logging system
│   ├── time.odin          # Time management
│   ├── imgui.odin         # ImGui integration
│   └── asset_manager.odin # Asset management
├── assets/
│   └── scenes/            # Scene files
└── vendor/                # Third-party dependencies
```

## Components

The engine includes several built-in components:
- Transform: Position, rotation, and scale
- Renderer: Mesh and material rendering
- Camera: View and projection settings
- Light: Various light types (Directional, Point, Spot)
- Script: Custom behavior scripting

## Building

1. Install Odin compiler
2. Install Raylib
3. Clone the repository
4. Build with Odin:
```bash
odin build src -out:fenrir
```

## Usage

Run the engine in debug mode to access the editor interface:
```bash
./fenrir
```

### Editor Controls
- File Menu: New, Open, Save scenes
- Entity Menu: Create new entities and components
- Window Menu: Toggle Scene Tree and Inspector panels
- Scene Tree: View and select entities
- Inspector: Edit component properties

## Dependencies

- Odin Programming Language
- Raylib
- ImGui (included in vendor directory)

## Credits

This project uses the [raylib-imgui-odin-template](https://github.com/Georgefwm/raylib-imgui-odin-template) as a foundation for ImGui integration with Raylib in Odin. The template provided the initial setup and implementation for the editor interface.

### Fresh installation using this template requires to do the folloring.

```bash
git submodule deinit -f vendor/odin-imgui
git rm -f vendor/odin-imgui
rm -rf .git/modules/vendor/odin-imgui
git submodule add https://gitlab.com/L-4/odin-imgui.git vendor/odin-imgui
git submodule update --init --recursive
```

Building L4's odin-imgui is entirely automated, using build.py. All platforms should work (not not: open an issue!), but currently Mac backends are untested as I don't have a Mac (help wanted!)

- dear_bindings depends on a library called "ply". link. You can probably install this with python -m pip install ply
- Windows depends on that vcvarsall.bat is in your path.
- Run python build.py

## License

MIT License