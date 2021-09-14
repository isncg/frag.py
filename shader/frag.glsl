#version 330
uniform sampler2D image;
uniform float time;
in vec2 uv;
out vec4 out_color;
const float PI = 3.14159265f;

void rgb()
{
    vec3 tex = texture(image, uv).rgb;
    vec3 col = vec3(sin(time*0.7+uv.x*2), sin(time+uv.y*2), cos(time*1.4+uv.x*2))*0.5 + vec3(0.5,0.5,0.5);
    vec3 col2 = vec3(col.x*tex.r, col.y*tex.g, col.z*tex.b);
    
    out_color = vec4(col2, 1.0);
}

void spin()
{
    float l = 2 - sqrt(pow(uv.x-0.5, 2) + pow(uv.y-0.5, 2))*2;
    float r = 2*pow(tan(time*0.5), 3)*l*(2-l);
    float u = uv.x - 0.5;
    float v = uv.y - 0.5;
    float u1 = cos(r)*u - sin(r)*v;
    float v1 = sin(r)*u + cos(r)*v;
    out_color = texture(image, vec2(u1+0.5, v1+0.5));
}


void main() {

    // float l = 1 - pow(uv.x-0.5, 2) - pow(uv.y-0.5, 2);
    // float r = 4*sin(time+l*sin(time));
    // float u = uv.x - 0.5;
    // float v = uv.y - 0.5;
    // float u1 = sin(r)*u - cos(r)*v;
    // float v1 = cos(r)*u + sin(r)*v;
    // out_color = texture(image, vec2(u1+0.5, v1+0.5));

    spin();
    //
    // float shift = sin(time+uv.x*24)*0.02;
    // out_color = texture(image, vec2(uv.x, uv.y+shift));
}
