
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

// in: float2 uv[0,1], float2 スケール係数(1=等倍, <1=拡大, >1=縮小)  out: float2 中心基準でスケールしたuv
float2 scale(float2 uv, float2 factor)
{
    return (uv - 0.5) * factor + 0.5;
}

// in: float2 uv[0,1], float スケール係数  out: float2 中心基準でスケールしたuv
float2 scale(float2 uv, float factor)
{
    return scale(uv, float2(factor, factor));
}