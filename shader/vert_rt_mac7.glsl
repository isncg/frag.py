// GLSL Code
#version 330 core
in vec2 in_position;
in vec2 in_uv;
out vec2 screenCoord;

void main()
{
	gl_Position = vec4(in_position, 0.0, 1.0);
    screenCoord = in_uv;
	//screenCoord = (in_position + 1.0) / 2.0;
}