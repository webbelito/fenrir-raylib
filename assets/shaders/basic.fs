#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Uniform inputs
uniform sampler2D texture0;
uniform vec4 colDiffuse;

void main()
{
    // Get texture color
    vec4 texelColor = texture(texture0, fragTexCoord);
    
    // Apply color tint
    finalColor = texelColor * colDiffuse * fragColor;
} 