shader_type spatial;

// Customizable parameters
uniform vec4 water_color : source_color = vec4(0.1, 0.3, 0.5, 0.8);
uniform float wave_speed = 0.5;
uniform float wave_strength = 0.2;
uniform sampler2D noise_texture : hint_default_white;
uniform float reflection_strength = 0.5;
uniform float refraction_strength = 0.1;
uniform float fresnel_power = 5.0;

varying vec3 vertex_position;

void vertex() {
    vertex_position = VERTEX;
    
    // Create wave movement
    float wave_x = sin(VERTEX.x * 2.0 + TIME * wave_speed) * wave_strength;
    float wave_z = cos(VERTEX.z * 2.0 + TIME * wave_speed) * wave_strength;
    VERTEX.y += wave_x + wave_z;
    
    // Adjust normal for lighting
    NORMAL = normalize(vec3(wave_x, 1.0, wave_z));
}

void fragment() {
    // Basic water color
    ALBEDO = water_color.rgb;
    
    // Add transparency
    ALPHA = water_color.a;
    
    // Calculate fresnel effect
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    
    // Add reflection and refraction
    vec2 reflection_uv = SCREEN_UV + (NORMAL.xy * reflection_strength);
    vec2 refraction_uv = SCREEN_UV + (NORMAL.xy * refraction_strength);
    
    // Mix with noise texture for more realistic water effect
    vec2 noise_uv = vertex_position.xz * 0.1 + TIME * 0.05;
    vec4 noise = texture(noise_texture, noise_uv);
    
    // PBR parameters
    METALLIC = 0.1;
    ROUGHNESS = 0.1;
    SPECULAR = 0.5;
}