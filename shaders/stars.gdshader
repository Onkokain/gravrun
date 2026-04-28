shader_type canvas_item;

uniform vec4 sky_color : source_color = vec4(0.01, 0.02, 0.08, 1.0);
uniform vec4 star_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float star_density : hint_range(50.0, 1000.0) = 300.0;
uniform float star_threshold : hint_range(0.90, 0.999) = 0.992;
uniform float star_size : hint_range(0.001, 0.05) = 0.01;

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    vec2 uv = UV;

    vec2 grid_uv = uv * star_density;
    vec2 cell = floor(grid_uv);
    vec2 local = fract(grid_uv) - 0.5;

    vec4 col = sky_color;

    float rnd = hash(cell);

    if (rnd > star_threshold) {
        float d = length(local);
        float star = smoothstep(star_size, 0.0, d);
        col += star_color * star;
    }

    COLOR = col;
}