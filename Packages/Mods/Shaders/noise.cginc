#ifndef AMENONE_NOISE_INCLUEDED
#define AMENONE_NOISE_INCLUEDED
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
            
// in: float2 任意の座標  out: float2 [0,1] の乱数
float2 hash22(float2 p)
{
    uint x = asuint(p.x);
    uint y = asuint(p.y);
    uint2 n = uint2(x, y);
    return float2( uhash22(n)) /  float(0xffffffffu) ;
}

// in: float2 任意の座標  out: float3 [0,1] の乱数
float3 hash23(float2 p)
{
    uint x = asuint(p.x);
    uint y = asuint(p.y);
    uint2 n = uint2(x, y);
    uint2 h0 = uhash22(n);
    uint2 h1 = uhash22(n + uint2(1u, 0u));
    return float3(h0, h1.x) / float(0xffffffffu);
}


// in: float2 任意の座標  out: half [0,1] の乱数（スカラー）
half random(in float2 st)
{
    uint2 n = asuint(float2(st));
    return float2(uhash22(n)).x / float(0xffffffffu);
}

// in: half2 任意の座標  out: half [0,1] のバイリニア補間ノイズ
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

// in: half2 座標, half 初期振幅, int オクターブ数  out: half ノイズをオクターブ重ねした値
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
// in: float2 座標, float グラデーション方向のランダム化係数(推奨: 1/41≒0.0244)  out: float [-1,1] のシンプレックスノイズ値
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

// in: float2 座標  out: float [-1,1] のシンプレックスノイズ値
float simplex_noise(float2 v)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    return simplex_noise(v,gradiant_dir_randomizer);
}

// 値と解析勾配を同時に返す simplex noise（Gustavson/McEwan の sdnoise 方式）
// in : float2 座標, float グラデーション方向のランダム化係数(推奨: 1/41≒0.0244)
// out: float3 .x = ノイズ値([-1,1]、simplex_noise と同一), .yz = 勾配(∂/∂x, ∂/∂y)
float3 simplex_noise_deriv(float2 v, float gradiantDirRandomizer)
{
    const float cx = 0.211324865405187;    // (3.0-sqrt(3.0))/6.0
    const float cy = 0.3660254037844387;   // 0.5*(sqrt(3.0)-1.0)
    const float cz = -0.5773502691896257;  // -1.0 + 2.0 * C.x
    float4 C = float4(cx, cy, cz, gradiantDirRandomizer);

    // First corner (x0)
    float2 i  = floor(v + dot(v, C.yy));
    float2 x0 = v - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 x1 = x0 + C.xx - i1;
    float2 x2 = x0 + C.zz;

    // Permutations
    i = mod289(i);
    float3 p = permute(
            permute(i.y + float3(0.0, i1.y, 1.0))
                  + i.x + float3(0.0, i1.x, 1.0));

    // 各コーナーの放射フォールオフ t = max(0.5 - |X|^2, 0)（既存 m の素）
    float3 t  = max(0.5 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0.0);
    float3 t2 = t * t;
    float3 t3 = t2 * t;
    float3 t4 = t2 * t2;

    // 勾配ベクトル選択（既存と同一）
    float3 x  = 2.0 * frac(p * C.www) - 1.0;
    float3 h  = abs(x) - 0.5;
    float3 ox = floor(x + 0.5);
    float3 a0 = x - ox;

    // 暗黙正規化係数（i 由来なので v に対して定数）
    float3 norm = 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    // g_i = grad_i · X_i（既存と同一）
    float3 g;
    g.x  = a0.x  * x0.x + h.x  * x0.y;
    g.yz = a0.yz * float2(x1.x, x2.x) + h.yz * float2(x1.y, x2.y);

    float3 m = norm * t4;               // 既存 simplex_noise の最終 m と一致
    float value = 130.0 * dot(m, g);    // 既存の返り値と完全一致

    // 勾配: d/dv[130 Σ norm t^4 g] = 130 Σ norm(-8 t^3 g X + t^4 grad)
    float3 c = -8.0 * t3 * g;           // 各コーナーの X に掛かる係数
    float2 deriv =
        norm.x * (c.x * x0 + t4.x * float2(a0.x, h.x)) +
        norm.y * (c.y * x1 + t4.y * float2(a0.y, h.y)) +
        norm.z * (c.z * x2 + t4.z * float2(a0.z, h.z));
    deriv *= 130.0;

    return float3(value, deriv);
}

// in : float2 座標  out: float3 .x = ノイズ値, .yz = 勾配(∂/∂x, ∂/∂y)
float3 simplex_noise_deriv(float2 v)
{
    const float gradiant_dir_randomizer = 0.024390243902439; // 1.0 / 41.0
    return simplex_noise_deriv(v, gradiant_dir_randomizer);
}

// in: half2 座標, half 初期振幅, int オクターブ数, float グラデーション方向のランダム化係数  out: half 乱流ノイズ値（絶対値fbm）
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
// in: half2 座標, half 初期振幅, int オクターブ数  out: half 乱流ノイズ値
half turbulence(in half2 st,half amplitude ,int NUM_OCTAVES)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    half v = turbulence(st,amplitude,NUM_OCTAVES,gradiant_dir_randomizer);
    return v;
}

// in: half2 座標, half 初期振幅, int オクターブ数, float オフセット(稜線の高さ), int 縁の鋭さ, float グラデーション方向のランダム化係数  out: half 稜線状ノイズ値
half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset,int edgePow,float gradiantDirRandomizer)
{
    half v = turbulence(st,amplitude,NUM_OCTAVES,gradiantDirRandomizer);
    v = offset - v;
    v = pow(v,edgePow);
    v = max(v,0);
    return v;
}
// in: half2 座標, half 初期振幅, int オクターブ数, float オフセット, int 縁の鋭さ  out: half 稜線状ノイズ値
half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset,int edgePow)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    half v = ridge(st,amplitude,NUM_OCTAVES,offset,edgePow,gradiant_dir_randomizer);
    return v;
}
// in: half2 座標, half 初期振幅, int オクターブ数, float オフセット  out: half 稜線状ノイズ値（edgePow=2）
half ridge(in half2 st,half amplitude ,int NUM_OCTAVES,float offset)
{
    const float gradiant_dir_randomizer = 0.024390243902439;// 1.0 / 41.0
    const int default_edgePow = 2;
    half v = ridge(st,amplitude,NUM_OCTAVES,offset,default_edgePow,gradiant_dir_randomizer);
    return v;
}

// in: float2 正規化済み座標, float2 セルオフセット(位相)  out: float4 .x=F1(最近傍距離) .y=F2(2番目の距離) .zw=最近傍セルID
float4 _cellularBase(float2 v, float2 cellOffset) {
    float F1 = 999.0;
    float F2 = 999.0;
    float2 nearestId = float2(0.0, 0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 cell = floor(v) + float2(x, y);
            float2 randomVal = hash22(cell);
            float2 featurePoint = cell + 0.5 + 0.5 * sin(cellOffset + 6.28318 * randomVal);//sinで値を0-1間で連続させることで破綻を防ぐ
            float dist = length(v - featurePoint);

            if (dist < F1) {
                F2 = F1;
                F1 = dist;
                nearestId = randomVal;
            } else if (dist < F2) {
                F2 = dist;
            }
        }
    }
    return float4(F1, F2, nearestId);
}


// in: float2 座標, float セルサイズ, float ぼかし量[0=シャープ,1=ぼかし], float2 セルオフセット(位相)  out: float2 .x=ノイズ値 .y=重み付きセルID
float2 voronoi_blur(float2 x, float cell_size, float blur, float2 cellOffset)
{
    float2 v = x / cell_size;
    float2 p = floor(v);
    float2 f = frac(v);

    float k = 1.0 + 63.0 * pow(1.0 - blur, 4.0);

    float va = 0.0;
    float idSum = 0.0;
    float wt = 0.0;

    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            float2 cell = p + float2(i, j);
            float2 randomVal = hash22(cell);
            float2 featurePoint = cell + 0.5 + 0.5 * sin(cellOffset + 6.28318 * randomVal);
            float dist = length(featurePoint - v);
            float ww = pow(1.0 - smoothstep(0.0, 1.414, dist), k);
            va += randomVal.y * ww;
            idSum += randomVal.x * ww;
            wt += ww;
        }
    }

    return float2(va / wt, idSum / wt);
}

float4 _cellularBase(float2 v) {
    return _cellularBase(v, float2(0.0, 0.0));
}

// in: float2 座標, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=最近傍距離F1 .y=最近傍セルID
float2 voronoi(float2 v, float cell_size, float2 cellOffset) {
    float4 c = _cellularBase(v/cell_size, cellOffset);
    return float2(c.x, c.z);
}
float2 voronoi(float2 v, float cell_size) {
    return voronoi(v, cell_size, float2(0.0, 0.0));
}

// in: float2 座標, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=F2-F1(境界で高くなる) .y=最近傍セルID
float2 cellular(float2 v, float cell_size, float2 cellOffset) {
    float4 c = _cellularBase(v/cell_size, cellOffset);
    return float2(c.y - c.x, c.z);
}
float2 cellular(float2 v, float cell_size) {
    return cellular(v, cell_size, float2(0.0, 0.0));
}

// in: float2 座標, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=F1/F2(境界で1に近づく) .y=最近傍セルID
float2 voronoi_normalized(float2 v, float cell_size, float2 cellOffset) {
    float4 c = _cellularBase(v/cell_size, cellOffset);
    return float2(c.x / c.y, c.z);
}
float2 voronoi_normalized(float2 v, float cell_size) {
    return voronoi_normalized(v, cell_size, float2(0.0, 0.0));
}

// in: half2 座標, half 初期振幅, int オクターブ数, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=voronoiのfbm値 .y=セルIDの累積平均
float2 fbm_voronoi(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half idSum = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        float2 c = voronoi(st, cell_size, cellOffset);
        v += a * c.x;
        idSum += c.y;
        st = st * 2.0;
        a *= 0.5;
    }

    return float2(v, idSum / NUM_OCTAVES);
}
float2 fbm_voronoi(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size)
{
    return fbm_voronoi(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

// in: half2 座標, half 初期振幅, int オクターブ数, float セルサイズ, float2 セルオフセット(位相), float ぼかし量[0,1]  out: float2 .x=voronoi_blurのfbm値 .y=セルIDの累積平均
float2 fbm_voronoi_blur(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset,float blur)
{
    half v = 0.0;
    half idSum = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        float2 c = voronoi_blur(st, cell_size, blur,cellOffset);
        v += a * c.x;
        idSum += c.y;
        st = st * 2.0;
        a *= 0.5;
    }

    return float2(v, idSum / NUM_OCTAVES);
}

float2 fbm_voronoi_blur(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size,float blur)
{
    return fbm_voronoi_blur(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0), blur);
}


// in: half2 座標, half 初期振幅, int オクターブ数, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=cellularのfbm値 .y=セルIDの累積平均
float2 fbm_cellular(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half idSum = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        float2 c = cellular(st, cell_size, cellOffset);
        v += a * c.x;
        idSum += c.y;
        st = st * 2.0;
        a *= 0.5;
    }

    return float2(v, idSum / NUM_OCTAVES);
}
float2 fbm_cellular(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size)
{
    return fbm_cellular(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

// in: half2 座標, half 初期振幅, int オクターブ数, float セルサイズ, float2 セルオフセット(位相)  out: float2 .x=voronoi_normalizedのfbm値 .y=セルIDの累積平均
float2 fbm_voronoi_normalized(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size, float2 cellOffset)
{
    half v = 0.0;
    half idSum = 0.0;
    half a = amplitude;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        float2 c = voronoi_normalized(st, cell_size, cellOffset);
        v += a * c.x;
        idSum += c.y;
        st = st * 2.0;
        a *= 0.5;
    }

    return float2(v, idSum / NUM_OCTAVES);
}
float2 fbm_voronoi_normalized(in half2 st, half amplitude, int NUM_OCTAVES, float cell_size)
{
    return fbm_voronoi_normalized(st, amplitude, NUM_OCTAVES, cell_size, float2(0.0, 0.0));
}

float2 voronoi_blur(float2 x, float cell_size, float blur)
{
    return voronoi_blur(x, cell_size, blur, float2(0.0, 0.0));
}

// 入力ポイントをずらした値でノイズ生成し、結果の勾配をベクトルとして出力する。
float3 curl_noise(float3 p, float cell_size, float gradiantDirRandomizer)
{
    float3 v = p / cell_size;
    const float e = 0.1;
    const float divisor = 1.0 / (2.0 * e);

    float3 dx = float3(e, 0.0, 0.0);
    float3 dy = float3(0.0, e, 0.0);
    float3 dz = float3(0.0, 0.0, e);

    const float2 seed2 = float2(5.2, 1.3);
    const float2 seed3 = float2(1.7, 9.2);

    float x = (simplex_noise((v + dy).xy + seed3, gradiantDirRandomizer) - simplex_noise((v - dy).xy + seed3, gradiantDirRandomizer))
            - (simplex_noise((v + dz).xz + seed2, gradiantDirRandomizer) - simplex_noise((v - dz).xz + seed2, gradiantDirRandomizer));

    float y = (simplex_noise((v + dz).yz,         gradiantDirRandomizer) - simplex_noise((v - dz).yz,         gradiantDirRandomizer))
            - (simplex_noise((v + dx).xy + seed3, gradiantDirRandomizer) - simplex_noise((v - dx).xy + seed3, gradiantDirRandomizer));

    float z = (simplex_noise((v + dx).xz + seed2, gradiantDirRandomizer) - simplex_noise((v - dx).xz + seed2, gradiantDirRandomizer))
            - (simplex_noise((v + dy).yz,         gradiantDirRandomizer) - simplex_noise((v - dy).yz,         gradiantDirRandomizer));

    return float3(x, y, z) * divisor;
}

float3 curl_noise(float3 p, float cell_size)
{
    const float gradiant_dir_randomizer = 0.024390243902439;
    return curl_noise(p, cell_size, gradiant_dir_randomizer);
}

float3 curl_noise(float3 p)
{
    return curl_noise(p, 1.0);
}

//curlのfbm版 計算負荷が非常に高い
float3 curl_noise_fbm(float3 p, half amplitude, int NUM_OCTAVES)
{
    const float e = 0.1;
    const float divisor = 1.0 / (2.0 * e);

    float3 dx = float3(e, 0.0, 0.0);
    float3 dy = float3(0.0, e, 0.0);
    float3 dz = float3(0.0, 0.0, e);

    const float2 seed2 = float2(5.2, 1.3);
    const float2 seed3 = float2(1.7, 9.2);

    float x = (fbm((p + dy).xy + seed3, amplitude, NUM_OCTAVES) - fbm((p - dy).xy + seed3, amplitude, NUM_OCTAVES))
            - (fbm((p + dz).xz + seed2, amplitude, NUM_OCTAVES) - fbm((p - dz).xz + seed2, amplitude, NUM_OCTAVES));

    float y = (fbm((p + dz).yz,         amplitude, NUM_OCTAVES) - fbm((p - dz).yz,         amplitude, NUM_OCTAVES))
            - (fbm((p + dx).xy + seed3, amplitude, NUM_OCTAVES) - fbm((p - dx).xy + seed3, amplitude, NUM_OCTAVES));

    float z = (fbm((p + dx).xz + seed2, amplitude, NUM_OCTAVES) - fbm((p - dx).xz + seed2, amplitude, NUM_OCTAVES))
            - (fbm((p + dy).yz,         amplitude, NUM_OCTAVES) - fbm((p - dy).yz,         amplitude, NUM_OCTAVES));

    return float3(x, y, z) * divisor;
}

// in: half2 座標, half 初期振幅, int オクターブ数, float ワープ強度, float 時間  out: float 2段ドメインワープ値, q/rは中間の歪みベクトル(色付け等に利用可)
float domain_warp(in half2 st, half amplitude, int NUM_OCTAVES, float warpStrength, float time, out float2 q, out float2 r)
{
    q = float2(
        fbm(st,                    amplitude, NUM_OCTAVES),
        fbm(st + float2(1.0, 1.0), amplitude, NUM_OCTAVES));

    r = float2(
        fbm(st + warpStrength * q + float2(1.7, 9.2) + 0.15  * time, amplitude, NUM_OCTAVES),
        fbm(st + warpStrength * q + float2(8.3, 2.8) + 0.126 * time, amplitude, NUM_OCTAVES));

    return fbm(st + warpStrength * r, amplitude, NUM_OCTAVES);
}

float domain_warp(in half2 st, half amplitude, int NUM_OCTAVES, float warpStrength, float time)
{
    float2 q, r;
    return domain_warp(st, amplitude, NUM_OCTAVES, warpStrength, time, q, r);
}

float domain_warp(in half2 st, half amplitude, int NUM_OCTAVES, float warpStrength)
{
    return domain_warp(st, amplitude, NUM_OCTAVES, warpStrength, 0.0);
}

float domain_warp(in half2 st, half amplitude, int NUM_OCTAVES)
{
    return domain_warp(st, amplitude, NUM_OCTAVES, 1.0);
}
#endif


