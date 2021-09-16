#version 330
uniform sampler2D image;
uniform float time;
uniform vec2 size;
in vec2 uv;
out vec4 out_color;
const float PI = 3.14159265f;

void main() {
	float aspect = 1.0;//size.x/size.y;
    float l = 1.414 - sqrt(pow(uv.x - 0.5, 2) + pow(uv.y - 0.5, 2)) * 2;
    float r = pow(tan(time * 0.4), 3) * l;
    float gain = max(0.0, -cos(time*0.8)*2-1);
    float x = uv.x - 0.5;
    float y = (uv.y - 0.5)/aspect;
    float x1 = cos(r) * x - sin(r) * y;
    float y1 = (sin(r) * x + cos(r) * y)*aspect;
    vec3 rgb1 = texture(image, vec2(x1 + 0.5, y1 + 0.5)).rgb;
    vec3 gainColor = (vec3(1.0,1.0,1.0) - rgb1)*gain;
    out_color = vec4(rgb1 + gainColor, 1.0);
}