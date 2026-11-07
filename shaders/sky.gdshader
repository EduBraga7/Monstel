shader_type canvas_item;
// Céu do hotel: gradiente por hora do dia, estrelas piscando, lua e brilho no horizonte.

uniform vec4 top_color : source_color = vec4(0.04, 0.02, 0.13, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.18, 0.08, 0.32, 1.0);
uniform float night = 1.0;       // 0 = dia, 1 = noite
uniform float scroll = 0.0;      // rolagem da câmera (parallax)
uniform float aspect = 0.5625;   // largura / altura da tela
uniform float time_s = 0.0;
uniform vec2 moon_pos = vec2(0.80, 0.14);   // posição da lua (0..1 da tela)

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, pow(uv.y, 1.15));

	// estrelas (uma por célula, algumas células vazias)
	vec2 grid = vec2(34.0 * aspect * 1.7778, 34.0);
	vec2 p = vec2(uv.x, uv.y + scroll * 0.00006) * grid;
	vec2 id = floor(p);
	vec2 f = fract(p);
	float h = hash21(id);
	vec2 sp = vec2(hash21(id + 3.1), hash21(id + 7.7)) * 0.7 + 0.15;
	float d = length(f - sp);
	float star = step(0.9, h) * smoothstep(0.09, 0.0, d);
	float tw = 0.55 + 0.45 * sin(time_s * 2.3 + h * 50.0);
	col += vec3(1.0, 0.96, 0.85) * star * tw * night * (1.0 - uv.y * 0.7);

	// lua com halo
	vec2 mp = vec2(moon_pos.x, moon_pos.y + scroll * 0.00002);
	vec2 dv = (uv - mp) * vec2(aspect * 1.7778, 1.0);
	float md = length(dv);
	float halo = smoothstep(0.26, 0.0, md);
	float disc = smoothstep(0.052, 0.047, md);
	float bite = smoothstep(0.046, 0.041, length(dv - vec2(0.022, -0.011)));
	vec3 moon_col = vec3(1.0, 0.95, 0.78);
	col += moon_col * halo * 0.16 * night;
	col = mix(col, moon_col, disc * (1.0 - bite * 0.9) * night);

	// brilho laranja leve perto do horizonte ao entardecer/amanhecer
	float glow = smoothstep(0.55, 1.0, uv.y) * (1.0 - abs(night - 0.5) * 2.0);
	col += vec3(1.0, 0.45, 0.25) * glow * 0.25;

	COLOR = vec4(col, 1.0);
}
