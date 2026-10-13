#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 charSize;
    vec2 viewSize;
    int atlasCount;
    int isGrayscaled;
    float invAtlasCount;
    float progress;
};

layout(binding = 1) uniform sampler2D src;
layout(binding = 2) uniform sampler2D srcNext;
layout(binding = 3) uniform sampler2D atlas;

void main() {
    vec2 grid = viewSize / charSize;
    vec2 cellUV = (floor(qt_TexCoord0 * grid) + 0.5) / grid;
    vec2 localUV = fract(qt_TexCoord0 * grid);

    vec4 colorA = texture(src, cellUV);
    vec4 colorB = texture(srcNext, cellUV);

    float brightnessA = clamp(dot(colorA.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);
    float brightnessB = clamp(dot(colorB.rgb, vec3(0.299, 0.587, 0.114)), 0.0, 1.0);

    vec3 rgbA = mix(colorA.rgb, vec3(brightnessA), float(isGrayscaled));
    vec3 rgbB = mix(colorB.rgb, vec3(brightnessB), float(isGrayscaled));

    float charIdxA = floor(brightnessA * float(atlasCount - 1));
    float charIdxB = floor(brightnessB * float(atlasCount - 1));

    float centeredX = 0.25 + (localUV.x * 0.5);

    float maskA = texture(atlas, vec2((charIdxA + centeredX) * invAtlasCount, localUV.y)).a;
    float maskB = texture(atlas, vec2((charIdxB + centeredX) * invAtlasCount, localUV.y)).a;

    vec4 finalA = vec4(rgbA * maskA, colorA.a);
    vec4 finalB = vec4(rgbB * maskB, colorB.a);

    fragColor = mix(finalA, finalB, progress) * qt_Opacity;
}
