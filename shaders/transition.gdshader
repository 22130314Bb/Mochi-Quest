shader_type canvas_item;

uniform float lines : hint_range(1.0, 100.0) = 10.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float smoothness : hint_range(0.0, 1.0) = 0.05; // Controla a suavidade da borda
uniform float angle : hint_range(0.0, 360.0) = 45.0; // Rotação das linhas
uniform vec4 line_color_a : source_color = vec4(1.0);
uniform vec4 line_color_b : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec2 rotate(vec2 uv, float rotation_angle) {
    float rad = radians(rotation_angle);
    float c = cos(rad);
    float s = sin(rad);
    mat2 rotation_mat = mat2(vec2(c, -s), vec2(s, c));
    return (uv - 0.5) * rotation_mat + 0.5;
}

void fragment() {
    // Rotaciona as UVs para dar o efeito diagonal
    vec2 rotated_uv = rotate(UV, angle);
    
    // Cria o padrão de repetição vertical
    float pattern_y = fract(rotated_uv.y * lines);
    
    // Define se é uma linha par ou ímpar (para o efeito zíper)
    // 0.0 = esquerda para direita, 1.0 = direita para esquerda
    float direction = step(0.5, pattern_y); 
    
    // Ajusta o progresso baseado na direção
    // Se direction é 0, queremos ir de 0 a 1. Se é 1, invertemos a lógica.
    float progress = rotated_uv.x;
    if (direction > 0.5) {
        progress = 1.0 - rotated_uv.x;
    }
    
    // Calcula a máscara alpha usando smoothstep para evitar serrilhado
    float alpha = smoothstep(threshold - smoothness, threshold + smoothness, progress);
    
    // Inverte o alpha porque queremos que desapareça quando threshold aumenta
    alpha = 1.0 - alpha;

    // Escolhe a cor baseada na linha (A ou B)
    vec4 final_color = mix(line_color_a, line_color_b, direction);
    
    // Aplica a cor e o alpha calculado
    COLOR = vec4(final_color.rgb, final_color.a * alpha);
	
	// ... código anterior ...
    
    // LINHA NOVA: Se o threshold for 0 ou menor, força invisibilidade total
    if (threshold <= 0.0) {
        COLOR.a = 0.0;
    }
}
