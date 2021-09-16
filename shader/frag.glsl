#version 330
uniform sampler2D image;
// uniform float time;
// const float PI = 3.14159265f;
in vec2 uv;
out vec4 out_color;

void main() {
    out_color = texture2D(image, uv);
}
