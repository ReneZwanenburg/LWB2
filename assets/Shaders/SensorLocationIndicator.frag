#version 330

uniform sampler2D texture;
uniform vec3 color;

in vec2 texCoord;

layout(location = 0) out vec4 albedo; // rgb = albedo, a = specular level

void main()
{
	float alpha = texture2D(texture, texCoord).a;
	
	if(alpha < 0.5) discard;
	
	albedo = vec4(color, 0);
}