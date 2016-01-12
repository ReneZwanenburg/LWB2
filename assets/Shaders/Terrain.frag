#version 330

uniform sampler2D texture;
uniform vec3 color;

in vec3 viewNormal;
in vec2 texCoord;

layout(location = 0) out vec4 albedo; // rgb = albedo, a = specular level
layout(location = 1) out vec4 normal; // rgb = viewspace normal xyz, a = specular power / 128

void main()
{
	vec3 albedoSample = texture2D(texture, texCoord).rgb;
	// Dirty little trick to make the specular highlight a bit more interesting without full blown mapping
	float specularLevel = dot(albedoSample, vec3(1)) * 0.25 + 0.25;
	
	albedo = vec4(albedoSample * color, specularLevel);
	normal = vec4(viewNormal * 0.5 + 0.5, specularLevel + 0.25);
}