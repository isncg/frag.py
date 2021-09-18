#version 330
in vec2 in_position;
in vec2 in_uv;
out vec2 uv;
uniform ivec2 iResolution;
void main() {
    gl_Position = vec4(in_position, 0.0, 1.0);
    uv = vec2(iResolution.x * in_uv.x, iResolution.y*in_uv.y);
}