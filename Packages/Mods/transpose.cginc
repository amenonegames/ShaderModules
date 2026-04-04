
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

float2x2 _rot(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    float2x2 m = float2x2(c, -s, s, c);
    return m;
}

// in: float2 uv[0,1], float 回転量[0,1](0=0度, 1=360度)  out: float2 中心基準で回転したuv
float2 rotate(float2 uv, float angle)
{
    return mul(_rot(angle * 6.28318), uv - 0.5) + 0.5;
}

