#version 330
uniform sampler2D image;
uniform vec2 image_size;
uniform float conv_size_scale;
uniform vec2 clamp_range;
uniform vec2 feature_transform;
uniform int try_count;
uniform float try_step;

in vec2 uv;
out vec4 out_color;
const mat3 matConvX = mat3(-1.0, -2.0, -1.0, 0.0, 0.0, 0.0, 1.0, 2.0, 1.0);
const mat3 matConvY = mat3(1.0, 0.0, -1.0, 2.0, 0.0, -2.0, 1.0, 0.0, -1.0);

vec3 sampleColor(vec2 offset, float weight, float scale_factor) {
    scale_factor*=conv_size_scale;
    vec2 pos = vec2(uv.x + scale_factor * offset.x / image_size.x, uv.y + scale_factor * offset.y / image_size.y);
    return (texture(image, pos) * weight).xyz;
}

vec3 sampleConv(mat3 mat, float scale_factor) {
    vec3 result = vec3(0.0, 0.0, 0.0);
    result += sampleColor(vec2(-1, 1), mat[0][0], scale_factor);
    result += sampleColor(vec2(0, 1), mat[0][1], scale_factor);
    result += sampleColor(vec2(1, 1), mat[0][2], scale_factor);

    result += sampleColor(vec2(-1, 0), mat[1][0], scale_factor);
    result += sampleColor(vec2(0, 0), mat[1][1], scale_factor);
    result += sampleColor(vec2(1, 0), mat[1][2], scale_factor);

    result += sampleColor(vec2(-1, -1), mat[2][0], scale_factor);
    result += sampleColor(vec2(0, -1), mat[2][1], scale_factor);
    result += sampleColor(vec2(1, -1), mat[2][2], scale_factor);
    return result;
}

void main() {
    float scale_factor = 1.0;
    float feature = 0.0;
    for(int i=0;i<try_count;i++)
    {
        vec3 gradX = sampleConv(matConvX, scale_factor);
        vec3 gradY = sampleConv(matConvY, scale_factor);
        feature = max(feature, sqrt(dot(gradX, gradX) + dot(gradY, gradY)));
        scale_factor +=try_step;
    }
    feature = (clamp(feature, clamp_range.x, clamp_range.y) - clamp_range.x)/(clamp_range.y - clamp_range.x);
    out_color = vec4(vec3(feature_transform.x + feature_transform.y * feature), 1.0);
}