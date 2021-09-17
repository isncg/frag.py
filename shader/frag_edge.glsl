#version 330
uniform sampler2D image;
uniform vec2 image_size;
uniform float conv_size_scale;
uniform vec2 clamp_range;
uniform vec2 feature_transform;
in vec2 uv;
out vec4 out_color;
const mat3 matConvX = mat3(-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0);
const mat3 matConvY = mat3(1.0, 0.0, -1.0, 2.0, 0.0, -2.0, 1.0, 0.0, -1.0);

vec3 sampleColor(vec2 offset, float weight) {
    vec2 pos = vec2(uv.x + conv_size_scale * offset.x / image_size.x, uv.y + conv_size_scale * offset.y / image_size.y);
    return (texture(image, pos) * weight).xyz;
}

vec3 sampleConv(mat3 mat) {
    vec3 result = vec3(0.0, 0.0, 0.0);
    result += sampleColor(vec2(-1, 1), mat[0][0]);
    result += sampleColor(vec2(0, 1), mat[0][1]);
    result += sampleColor(vec2(1, 1), mat[0][2]);

    result += sampleColor(vec2(-1, 0), mat[1][0]);
    result += sampleColor(vec2(0, 0), mat[1][1]);
    result += sampleColor(vec2(1, 0), mat[1][2]);

    result += sampleColor(vec2(-1, -1), mat[2][0]);
    result += sampleColor(vec2(0, -1), mat[2][1]);
    result += sampleColor(vec2(1, -1), mat[2][2]);
    return result;
}

void main() {
    vec3 gradX = sampleConv(matConvX);
    vec3 gradY = sampleConv(matConvY);
    float feature = sqrt(dot(gradX, gradX) + dot(gradY, gradY));
    feature = (clamp(feature, clamp_range.x, clamp_range.y) - clamp_range.x)/(clamp_range.y - clamp_range.x);
    out_color = vec4(vec3(feature_transform.x + feature_transform.y * feature), 1.0);
}