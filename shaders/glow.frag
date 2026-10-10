#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix; float qt_Opacity;
    float fillMode; float imgW; float imgH; float scrW; float scrH;
    float time; float level; float strength; float bloom;
    vec4 color; float spotColors;
    vec4 b0; vec4 b1; vec4 b2; vec4 b3;
};
layout(binding = 1) uniform sampler2D coreTex;
layout(binding = 2) uniform sampler2D infoTex;
layout(binding = 3) uniform sampler2D distTex;
layout(binding = 4) uniform sampler2D colorTex;
float band(float p) {
    float x = clamp(p, 0.0, 1.0) * 15.0; int i = int(floor(x)); int j = min(i + 1, 15); float f = fract(x);
    float a[16] = float[16](b0.x,b0.y,b0.z,b0.w,b1.x,b1.y,b1.z,b1.w,b2.x,b2.y,b2.z,b2.w,b3.x,b3.y,b3.z,b3.w);
    return mix(a[i], a[j], f);
}
float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
vec2 imageUV(vec2 uv) {
    if (fillMode < 0.5) return uv;
    float s = max(scrW / imgW, scrH / imgH);
    vec2 scaled = vec2(imgW, imgH) * s;
    vec2 off = (scaled - vec2(scrW, scrH)) / scaled;
    return uv * (vec2(1.0) - off) + off * 0.5;
}
void main() {
    vec2 uv = imageUV(qt_TexCoord0);
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { fragColor = vec4(0.0); return; }
    vec4 info = texture(infoTex, uv);
    float halo = info.r;
    if (halo < 0.004) { fragColor = vec4(0.0); return; }
    float core = texture(coreTex, uv).r;
    float pos = info.g;
    float phase = info.b;
    float z = time * (5.0 + phase * 7.0) + phase * 97.0;
    float flicker = mix(hash(floor(z) + phase * 311.0), hash(floor(z)+1.0+phase*311.0), fract(z));
    float drive = band(0.25 + pos * 0.7) * 1.3 + level * 0.45;
    drive *= 0.45 + 0.85 * flicker * flicker;
    float light = core * strength * drive + halo * bloom * drive * 0.55;
    light = light / (1.0 + 0.35 * light);
    vec3 tone = spotColors > 0.5 ? texture(colorTex, uv).rgb : color.rgb;
    vec3 rgb = tone * light;
    rgb += vec3(1.0,0.92,0.8) * max(0.0, core * drive * strength - 0.9) * 0.35;
    // ShaderEffect uses alpha blending. A zero alpha makes the entire glow invisible.
    vec3 glow = clamp(rgb, 0.0, 1.0);
    float alpha = clamp(max(max(glow.r, glow.g), glow.b) * 0.82, 0.0, 0.82);
    fragColor = vec4(glow, alpha) * qt_Opacity;
}
