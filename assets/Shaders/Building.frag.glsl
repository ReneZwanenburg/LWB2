#version 330

layout(location = 0) out vec4 albedo; // rgb = albedo, a = diffuse level
layout(location = 1) out vec4 normal; // rgb = viewspace normal xyz, a = emission level
layout(location = 2) out vec2 surfaceParameters; // r = specular power / 128, g = specular level

in vec3 viewNormal;

uniform vec3 color;

void main()
{
	albedo = vec4(color, 1);
	normal = vec4(viewNormal * 0.5 + 0.5, 0);
	surfaceParameters = vec2(0.5, 0.5);
}