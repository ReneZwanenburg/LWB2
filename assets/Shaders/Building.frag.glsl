#version 330

layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 normal;

in vec3 viewNormal;

uniform vec3 color;

void main()
{
	albedo = vec4(color, 0.5);
	normal = vec4(viewNormal * 0.5 + 0.5, 0.5);
}