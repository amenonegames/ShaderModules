
uint2 uhash22(uint2 n)
{
    uint2 k = uint2(0x456789abu, 0x6789ab45);
    uint3 u = uint3(13, 17 ,15);
    n ^= (n.yx << u.xy);
    n ^= (n.yx >> u.yz);
    n *= k.xy;
    n ^= (n.yx << u.zx);
    return n * k.xy;
}
            
float2 hash22(float2 p)
{
    uint x = asuint(p.x);
    uint y = asuint(p.y);
    uint2 n = uint2(x, y);
    return float2( uhash22(n)) /  float(0xffffffffu) ;
}


// Get random value
half random(in float2 st)
{
    uint2 n = asuint(float2(st));
    
    return float2( uhash22(n)) /  float(0xffffffffu) ;
}

// Get noise
half noise(in half2 st)
{
    // Splited integer and float values.
    half2 i = floor(st);
    half2 f = frac(st);

    float a = random(i + half2(0.0, 0.0));
    float b = random(i + half2(1.0, 0.0));
    float c = random(i + half2(0.0, 1.0));
    float d = random(i + half2(1.0, 1.0));

    // -2.0f^3 + 3.0f^2
    half2 u = f * f * (3.0 - 2.0 * f);

    return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

half fbm(in half2 st,half amplitude ,int NUM_OCTAVES)
{
    half v = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * noise(st);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}

// mod289 - float3版
float3 mod289(float3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

// mod289 - float2版（snoise内のiに使う）
float2 mod289(float2 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

// permute
float3 permute(float3 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

//
// Description : GLSL 2D simplex noise function
//      Author : Ian McEwan, Ashima Arts
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License :
//  Copyright (C) 2011 Ashima Arts. All rights reserved.
//  Distributed under the MIT License. See LICENSE file.
//  https://github.com/ashima/webgl-noise
//
float simplex_noise(float2 v , float gradiantDirRandomizer) {
    const float cx  =0.211324865405187;    // (3.0-sqrt(3.0))/6.0
    const float cy  =0.3660254037844387;    // 0.5*(sqrt(3.0)-1.0)
    const float cz  =-0.5773502691896257;    // -1.0 + 2.0 * C.x
    // Precompute values for skewed triangular grid
    float4 C = float4(cx, cy, cz, gradiantDirRandomizer);
    // First corner (x0)
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    float2 i1 = float2(0,0);
    i1 = (x0.x > x0.y)? float2(1.0, 0.0):float2(0.0, 1.0);
    float2 x1 = x0.xy + C.xx - i1;
    float2 x2 = x0.xy + C.zz;

    // Do some permutations to avoid
    // truncation effects in permutation
    i = mod289(i);
    float3 p = permute(
            permute( i.y + float3(0.0, i1.y, 1.0))
                + i.x + float3(0.0, i1.x, 1.0 ));

    float3 m = max(0.5 - float3(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2)
                        ), 0.0);

    m = m*m ;
    m = m*m ;

    // Gradients:
    //  41 pts uniformly over a line, mapped onto a diamond
    //  The ring size 17*17 = 289 is close to a multiple
    //      of 41 (41*7 = 287)

    float3 x = 2.0 * frac(p * C.www) - 1.0;
    float3 h = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt(a0*a0 + h*h);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

    // Compute final noise value at P
    float3 g = float3(0,0,0);
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * float2(x1.x,x2.x) + h.yz * float2(x1.y,x2.y);
    return 130.0 * dot(m, g);
}

float simplex_noise(float2 v)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    return simplex_noise(v,gradiant_dir_randomizer);
}

half turbulence(in half2 st,half amplitude ,int NUM_OCTAVES , float gradiantDirRandomizer)
{
    half v = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * abs(simplex_noise(st,gradiantDirRandomizer));
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}
half turbulence(in half2 st,half amplitude ,int NUM_OCTAVES)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    half v = turbulence(st,amplitude,NUM_OCTAVES,gradiant_dir_randomizer);
    return v;
}

half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset,int edgePow,float gradiantDirRandomizer)
{
    half v = turbulence(st,amplitude,NUM_OCTAVES,gradiantDirRandomizer);
    v = offset - v;
    v = pow(v,edgePow);
    v = max(v,0);
    return v;
}
half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset,int edgePow)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    half v = ridge(st,amplitude,NUM_OCTAVES,offset,edgePow,gradiant_dir_randomizer);
    return v;
}
half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    const int default_edgePow = 2;
    half v = ridge(st,amplitude,NUM_OCTAVES,offset,default_edgePow,gradiant_dir_randomizer);
    return v;
}
// 内部用はアンダースコアで「これは内部実装だよ」と示す慣習
float2 _cellularBase(float2 v, float2 cellOffset) {
    float F1 = 999.0;
    float F2 = 999.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 cell = floor(v) + float2(x, y);
            float2 randomVal = hash22(cell);
            float2 featurePoint = cell + 0.5 + 0.5 * sin(cellOffset + 6.28318 * randomVal);//sinで値を0-1間で連続させることで破綻を防ぐ
            float dist = length(v - featurePoint);

            if (dist < F1) {
                F2 = F1;
                F1 = dist;
            } else if (dist < F2) {
                F2 = dist;
            }
        }
    }

    return float2(F1, F2);
}

float2 _cellularBase(float2 v) {
    return _cellularBase(v, float2(0.0, 0.0));
}

float voronoi(float2 v, float cell_size, float2 cellOffset) {
    return _cellularBase(v/cell_size, cellOffset).x;
}
float voronoi(float2 v , float cell_size) {
    return voronoi(v, cell_size, float2(0.0, 0.0));
}

float cellular(float2 v, float cell_size, float2 cellOffset) {
    float2 c = _cellularBase(v/cell_size, cellOffset);
    return c.y - c.x;
}
float cellular(float2 v, float cell_size) {
    return cellular(v, cell_size, float2(0.0, 0.0));
}

float voronoi_normalized(float2 v, float cell_size, float2 cellOffset) {
    float2 c = _cellularBase(v/cell_size, cellOffset);
    return c.x / c.y;
}
float voronoi_normalized(float2 v, float cell_size) {
    return voronoi_normalized(v, cell_size, float2(0.0, 0.0));
}

float fbm_voronoi(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * voronoi(st, cell_size, cellOffset);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}
float fbm_voronoi(in half2 st,half amplitude ,int NUM_OCTAVES,float cell_size)
{
    return fbm_voronoi(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

float fbm_cellular(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * cellular(st, cell_size, cellOffset);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}
float fbm_cellular(in half2 st,half amplitude ,int NUM_OCTAVES,float cell_size)
{
    return fbm_cellular(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

float fbm_voronoi_normalized(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * voronoi_normalized(st, cell_size, cellOffset);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}
float fbm_voronoi_normalized(in half2 st,half amplitude ,int NUM_OCTAVES,float cell_size)
{
    return fbm_voronoi_normalized(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

