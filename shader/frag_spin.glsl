#version 330
uniform sampler2D image;
uniform float time;
in vec2 uv;
out vec4 out_color;
const float PI = 3.14159265f;

void main() {
    float l = 1.414 - sqrt(pow(uv.x - 0.5, 2) + pow(uv.y - 0.5, 2)) * 2;
    float r = pow(tan(time * 0.4), 3) * l;
    float gain = max(0.0, -cos(time*0.8)*2-1);
    float u = uv.x - 0.5;
    float v = uv.y - 0.5;
    float u1 = cos(r) * u - sin(r) * v;
    float v1 = sin(r) * u + cos(r) * v;
    vec3 rgb1 = texture(image, vec2(u1 + 0.5, v1 + 0.5)).rgb;
    vec3 gainColor = (vec3(1.0,1.0,1.0) - rgb1)*gain;
    out_color = vec4(rgb1 + gainColor, 1.0);
}