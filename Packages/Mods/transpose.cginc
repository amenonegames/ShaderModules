
// uv: [0,1] range, center at (0.5, 0.5)
// polar.x: radius from center
// polar.y: angle in radians [-PI, PI]

float2 uv_to_polar(float2 uv)
{
    float2 centered = uv - 0.5;
    float r = length(centered);
    float theta = atan2(centered.y, centered.x);
    return float2(r, theta);
}

float2 polar_to_uv(float2 polar)
{
    float2 centered = float2(cos(polar.y), sin(polar.y)) * polar.x;
    return centered + 0.5;
}
