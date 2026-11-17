#ifndef AMENONE_FRACTAL_INCLUEDED
#define AMENONE_FRACTAL_INCLUEDED
#include "Packages/com.amenone.shadermodules/Shaders/time.cginc"
#include "Packages/com.amenone.shadermodules/Shaders/transpose.cginc"
// 推奨反復回数は Switch(初代) 全画面 60fps を想定した見積もりで、実測値ではない。上限は 720p で細部が 1 ピクセル未満になる回数
static const float FRACTAL_PI = 3.14159265358979;
static const float FRACTAL_SQRT3 = 1.7320508;
static const float FRACTAL_GOLDEN_RATIO = 1.6180339887;
static const float FRACTAL_EDGE_SMOOTHING_PIXELS = 0.75;
static const float FRACTAL_MIN_JACOBIAN_AXES_SIN_SQUARED = 1e-6;

float _fractal_mod(float x, float y)
{
    return x - y * floor(x / y);
}

float2x2 _fractal_rotation(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, s, -s, c);
}

float2 _fractal_rotate_around_origin(float2 p, float angle)
{
    return rotate(p + 0.5, angle / (2.0 * FRACTAL_PI)) - 0.5;
}

float _fractal_exp_glow(float distanceToShape, float intensity, float sharpness)
{
    return intensity * exp(-distanceToShape * sharpness);
}

float _fractal_equilateral_triangle_distance(float2 p, float halfSide)
{
    p.x = abs(p.x) - halfSide;
    p.y = p.y + halfSide / FRACTAL_SQRT3;
    if (p.x + FRACTAL_SQRT3 * p.y > 0.0)
    {
        p = float2(p.x - FRACTAL_SQRT3 * p.y, -FRACTAL_SQRT3 * p.x - p.y) / 2.0;
    }
    p.x -= clamp(p.x, -2.0 * halfSide, 0.0);
    return -length(p) * sign(p.y);
}

float _fractal_box_distance(float2 p, float halfSize)
{
    float2 q = abs(p) - halfSize;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

// in: float 位置t, float3 色相の位相  out: float3 [0,1] のコサインパレット色
// 反復なし
float3 cosine_palette(float t, float3 phase)
{
    return 0.5 + 0.5 * cos(2.0 * FRACTAL_PI * (t + phase));
}

// in: float 1 周あたりの拡大率, float 進み具合（1 で 1 周）  out: float zoom_loop が中心からの距離に掛ける倍率
// 反復なし
float zoom_loop_scale(float zoomPerLoop, float progress)
{
    return pow(zoomPerLoop, -frac(progress));
}

// in: float2 座標, float2 ズームの中心, float 1 周あたりの拡大率, float 進み具合（1 で 1 周）  out: float2 中心へ拡大した座標。進み具合の整数部は無視するので、自己相似な中心と倍率を渡すと継ぎ目なく繰り返す
// 反復なし
float2 zoom_loop(float2 p, float2 center, float zoomPerLoop, float progress)
{
    return center + (p - center) * zoom_loop_scale(zoomPerLoop, progress);
}

// in: float2 座標, float 回転対称の数  out: float2 角度を segmentCount 等分して鏡映で折りたたんだ座標
// 反復なし
float2 fold_kaleidoscope(float2 p, float segmentCount)
{
    float halfSegmentAngle = FRACTAL_PI / segmentCount;
    float angle = atan2(p.y, p.x);
    angle = abs(_fractal_mod(angle, 2.0 * halfSegmentAngle) - halfSegmentAngle);
    return length(p) * float2(cos(angle), sin(angle));
}

// in: float2 座標, float 回転対称の数, float 折りたたむ前に原点まわりで回す角度（ラジアン）  out: float2 回してから角度を segmentCount 等分して鏡映で折りたたんだ座標
// 反復なし
float2 fold_kaleidoscope(float2 p, float segmentCount, float rotation)
{
    return fold_kaleidoscope(_fractal_rotate_around_origin(p, rotation), segmentCount);
}

// in: float2 座標  out: float 0.75 ピクセルに相当する座標の幅（smoothstep のぼかし幅に使う）
// 反復なし。fwidth を使うのでフラグメントシェーダー専用
float edge_smoothing_width(float2 p)
{
    float2 pixelSize = fwidth(p);
    return FRACTAL_EDGE_SMOOTHING_PIXELS * max(pixelSize.x, pixelSize.y);
}

// in: float 値, float2 値を評価した座標  out: float2 座標空間での値の勾配 (∂value/∂p.x, ∂value/∂p.y)。座標が画面上で 1 方向に潰れている所では 0
// 反復なし。ddx/ddy を使うのでフラグメントシェーダー専用
float2 screen_space_gradient(float value, float2 p)
{
    float valuePerPixelX = ddx(value);
    float valuePerPixelY = ddy(value);
    float2 pPerPixelX = ddx(p);
    float2 pPerPixelY = ddy(p);
    float determinant = pPerPixelX.x * pPerPixelY.y - pPerPixelX.y * pPerPixelY.x;
    if (determinant * determinant <= FRACTAL_MIN_JACOBIAN_AXES_SIN_SQUARED * dot(pPerPixelX, pPerPixelX) * dot(pPerPixelY, pPerPixelY))
    {
        return 0.0;
    }
    float2 gradientTimesDeterminant = float2(
        pPerPixelY.y * valuePerPixelX - pPerPixelX.y * valuePerPixelY,
        pPerPixelX.x * valuePerPixelY - pPerPixelY.x * valuePerPixelX);
    return gradientTimesDeterminant / determinant;
}

// in: float2 座標, int 反復回数, float2 折り返し後のずらし量, float 回転角, float 拡大率  out: float2 .x=折り目線までの距離 .y=原点への最小距離(軌道トラップ)
// 推奨反復回数: 8〜12（上限 16）
float2 fractal_kifs(float2 p, int iterations, float2 offset, float angle, float scale)
{
    float2x2 rotation = _fractal_rotation(angle);
    float totalScale = 1.0;
    float lineDistance = 1e9;
    float nearestDistance = 1e9;
    for (int i = 0; i < iterations; i++)
    {
        p = abs(p) - offset;
        p = mul(rotation, p);
        p *= scale;
        totalScale *= scale;
        lineDistance = min(lineDistance, abs(p.y) / totalScale);
        nearestDistance = min(nearestDistance, length(p));
    }
    return float2(lineDistance, nearestDistance);
}

// in: float2 座標, int 反復回数  out: float2 .x=折り目線までの距離 .y=原点への最小距離(軌道トラップ)
// 推奨反復回数: 8〜12（上限 16）
float2 fractal_kifs(float2 p, int iterations)
{
    return fractal_kifs(p, iterations, float2(0.5, 0.28), 0.62, 1.5);
}

// in: float2 座標, int 反復回数, float2 折り返し後のずらし量, float 回転角, float 拡大率, float 輪の半径  out: float2 .x=輪までの距離 .y=原点への最小距離(軌道トラップ)
// 推奨反復回数: 6〜10（上限 16）
float2 fractal_kifs_rings(float2 p, int iterations, float2 offset, float angle, float scale, float ringRadius)
{
    float2x2 rotation = _fractal_rotation(angle);
    float totalScale = 1.0;
    float ringDistance = 1e9;
    float nearestDistance = 1e9;
    for (int i = 0; i < iterations; i++)
    {
        p = abs(p) - offset;
        p = mul(rotation, p);
        p *= scale;
        totalScale *= scale;
        ringDistance = min(ringDistance, abs(length(p) - ringRadius) / totalScale);
        nearestDistance = min(nearestDistance, length(p));
    }
    return float2(ringDistance, nearestDistance);
}

// in: float2 座標（外接円半径 1・上向きの正三角形）, int 反復回数  out: float 符号付き距離（内側が負）
// 頂点 (0, 1) を中心に 2 倍で自己相似（1 段深い反復と対応）
// 推奨反復回数: 6〜8（上限 10）
float fractal_sierpinski_triangle(float2 p, int iterations)
{
    const float2 topVertex = float2(0.0, 1.0);
    const float2 mirrorNormal = float2(-0.5, 0.8660254);
    float totalScale = 1.0;
    for (int i = 0; i < iterations; i++)
    {
        p.x = abs(p.x);
        p -= 2.0 * min(0.0, dot(p, mirrorNormal)) * mirrorNormal;
        p.x = abs(p.x);
        p = 2.0 * p - topVertex;
        totalScale *= 2.0;
    }
    return _fractal_equilateral_triangle_distance(p, 0.8660254) / totalScale;
}

// in: float2 座標（原点中心・外接円半径 約 0.58）, int 反復回数  out: float 雪片の輪郭までの距離
// 3 つの先端 (±0.5, 0.2886751), (0, -0.5773503) を中心に 3 倍で自己相似（1 段深い反復と対応）
// 推奨反復回数: 4〜5（上限 6）
float fractal_koch_snowflake(float2 p, int iterations)
{
    float2 outerMirrorNormal = float2(sin(5.0 / 6.0 * FRACTAL_PI), cos(5.0 / 6.0 * FRACTAL_PI));
    float2 innerMirrorNormal = float2(sin(2.0 / 3.0 * FRACTAL_PI), cos(2.0 / 3.0 * FRACTAL_PI));
    p.x = abs(p.x);
    p.y += tan(5.0 / 6.0 * FRACTAL_PI) * 0.5;
    p -= outerMirrorNormal * max(0.0, dot(p - float2(0.5, 0.0), outerMirrorNormal)) * 2.0;
    p.x += 0.5;
    float totalScale = 1.0;
    for (int i = 0; i < iterations; i++)
    {
        p *= 3.0;
        totalScale *= 3.0;
        p.x -= 1.5;
        p.x = abs(p.x) - 0.5;
        p -= innerMirrorNormal * min(0.0, dot(p, innerMirrorNormal)) * 2.0;
    }
    return length(p - float2(clamp(p.x, -1.0, 1.0), 0.0)) / totalScale;
}

// in: float2 座標（[-1,1] の正方形）, int 反復回数  out: float 符号付き距離（内側が負）
// (±0.5, ±0.5) を中心に 9 倍で自己相似（2 段深い反復と対応）
// 推奨反復回数: 4〜5（上限 6）
float fractal_sierpinski_carpet(float2 p, int iterations)
{
    float totalScale = 1.0;
    for (int i = 0; i < iterations; i++)
    {
        p = abs(p);
        if (p.y > p.x)
        {
            p = p.yx;
        }
        p = float2(3.0 * p.x - 2.0, abs(3.0 * p.y - 1.0) - 1.0);
        totalScale *= 3.0;
    }
    return _fractal_box_distance(p, 1.0) / totalScale;
}

// in: float2 座標, int 反復回数, float 折りの倍率（-1.75 前後）  out: float3 .x=原点への最小距離の2乗 .y=軸への最小距離 .z=最終的な原点からの距離（大きいほど発散）
// 推奨反復回数: 8〜12（除算あり）
float3 fractal_box_fold(float2 p, int iterations, float foldScale)
{
    float2 z = p;
    float nearestDistanceSquared = 1e9;
    float axisDistance = 1e9;
    for (int i = 0; i < iterations; i++)
    {
        z = clamp(z, -1.0, 1.0) * 2.0 - z;
        float inversion = clamp(1.0 / max(dot(z, z), 1e-6), 1.0, 4.0);
        z = z * inversion * foldScale + p;
        nearestDistanceSquared = min(nearestDistanceSquared, dot(z, z));
        axisDistance = min(axisDistance, min(abs(z.x), abs(z.y)));
    }
    return float3(nearestDistanceSquared, axisDistance, length(z));
}

// in: float2 座標, int 反復回数, float 反転の強さ（1.1〜1.3）  out: float2 .x=線までの距離 .y=原点への最小距離の2乗
// 推奨反復回数: 6〜8（除算あり）
float2 fractal_apollonian(float2 p, int iterations, float strength)
{
    float totalScale = 1.0;
    float nearestDistanceSquared = 1e9;
    for (int i = 0; i < iterations; i++)
    {
        p = -1.0 + 2.0 * frac(0.5 * p + 0.5);
        float radiusSquared = max(dot(p, p), 1e-6);
        nearestDistanceSquared = min(nearestDistanceSquared, radiusSquared);
        float inversion = strength / radiusSquared;
        p *= inversion;
        totalScale *= inversion;
    }
    float lineDistance = 0.25 * abs(p.y) / totalScale;
    return float2(lineDistance, nearestDistanceSquared);
}

// in: float2 座標, int 反復回数, float2 毎回引く定数  out: float2 .x=光量[0,1]（反復平均） .y=原点への最小距離
// 推奨反復回数: 8〜12（除算と exp あり）
float2 fractal_kali(float2 p, int iterations, float2 offset)
{
    float nearestDistance = 1e9;
    float glowSum = 0.0;
    float previousRadius = length(p);
    for (int i = 0; i < iterations; i++)
    {
        p = abs(p) / max(dot(p, p), 1e-6) - offset;
        float radius = length(p);
        glowSum += exp(-6.0 * abs(radius - previousRadius));
        previousRadius = radius;
        nearestDistance = min(nearestDistance, radius);
    }
    float glow = glowSum / max((float)iterations, 1.0);
    return float2(glow, nearestDistance);
}

// in: float2 座標, int 反復回数, float 輪の位相, float パレットのずらし量, float3 パレットの位相  out: float3 輪の光を足し込んだ色
// 推奨反復回数: 3〜4（sin・pow・exp あり。上限 6）
float3 fractal_glow_rings(float2 p, int iterations, float ringPhase, float paletteShift, float3 palettePhase)
{
    float startRadius = length(p);
    float3 color = 0.0;
    for (int i = 0; i < iterations; i++)
    {
        p = frac(p * 1.5) - 0.5;
        float ring = length(p) * exp(-startRadius);
        float3 ringColor = cosine_palette(startRadius + i * 0.4 + paletteShift, palettePhase);
        ring = abs(sin(ring * 8.0 + ringPhase) / 8.0);
        color += ringColor * pow(0.01 / max(ring, 1e-4), 1.2);
    }
    return color;
}

// in: float2 座標, float2 らせんの収束点, float 90度回るごとの拡大率（1 だと 0 除算になる）  out: float2 .x=target まわりの角度（90度=1） .y=らせん座標。(x+4, y+1) は同じ点なので frac(coord * 整数) でタイル化する
// 反復なし
float2 log_spiral_coord(float2 p, float2 target, float growthPerQuarterTurn)
{
    float2 toTarget = p - target;
    float radius = max(length(toTarget), 1e-5);
    float logGrowth = log(growthPerQuarterTurn);
    float quarterTurns = atan2(toTarget.y, toTarget.x) / (FRACTAL_PI / 2.0);
    float spiral = (log(radius) + logGrowth * quarterTurns) / (4.0 * logGrowth);
    return float2(quarterTurns, spiral);
}

// in: float2 座標, float2 らせんの収束点  out: float2 黄金らせんの log_spiral_coord
// 反復なし
float2 golden_spiral_coord(float2 p, float2 target)
{
    return log_spiral_coord(p, target, FRACTAL_GOLDEN_RATIO);
}

// in: float2 座標, float2 吸い込む点, float2 湧き出す点, float 90度回るごとの拡大率（1 だと 0 除算になる）  out: float2 source から sink へ巻き込む log_spiral_coord と同じ形式の座標
// 反復なし
float2 double_spiral_coord(float2 p, float2 sink, float2 source, float growthPerQuarterTurn)
{
    float2 fromSink = p - sink;
    float2 fromSource = p - source;
    float sinkDistanceSquared = max(dot(fromSink, fromSink), 1e-9);
    float sourceDistanceSquared = max(dot(fromSource, fromSource), 1e-9);
    float2 mobius = float2(dot(fromSink, fromSource), fromSink.y * fromSource.x - fromSink.x * fromSource.y) / sourceDistanceSquared;
    float logGrowth = log(growthPerQuarterTurn);
    float quarterTurns = atan2(mobius.y, mobius.x) / (FRACTAL_PI / 2.0);
    float spiral = (0.5 * log(sinkDistanceSquared / sourceDistanceSquared) + logGrowth * quarterTurns) / (4.0 * logGrowth);
    return float2(quarterTurns, spiral);
}

// in: float2 らせん座標, float 1 単位あたりのタイル数（整数値）  out: float2 [-0.5,0.5] のタイル内座標
// 反復なし
float2 spiral_tile(float2 spiralCoord, float tilesPerUnit)
{
    return frac(spiralCoord * tilesPerUnit) - 0.5;
}

// in: float2 らせん座標, float 90度回るごとの拡大率  out: float らせん 1 本までの対数空間での距離
// 反復なし
float log_spiral_line_distance(float2 spiralCoord, float growthPerQuarterTurn)
{
    return abs(frac(spiralCoord.y + 0.5) - 0.5) * 4.0 * abs(log(growthPerQuarterTurn));
}

// log_spiral_coord は等角でないので、面積の拡大率から求めた等方近似
float _fractal_log_spiral_coord_unit_length(float2 p, float2 target, float growthPerQuarterTurn)
{
    return length(p - target) * sqrt(2.0 * FRACTAL_PI * abs(log(growthPerQuarterTurn)));
}

struct FractalKifsStyle
{
    float coordinateScale;
    int iterations;
    float2 offset;
    float angle;
    float angleAmplitude;
    float angleSpeed;
    float scale;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float lineGlowIntensity;
    float lineGlowSharpness;
    float haloGlowIntensity;
    float haloGlowSharpness;
};

// out: FractalKifsStyle fractal_kifs_color の推奨値
// 反復なし
FractalKifsStyle fractal_kifs_default_style()
{
    FractalKifsStyle style;
    style.coordinateScale = 1.3;
    style.iterations = 10;
    style.offset = float2(0.5, 0.28);
    style.angle = 0.62;
    style.angleAmplitude = 0.1;
    style.angleSpeed = 0.3;
    style.scale = 1.5;
    style.backgroundColor = float3(0.03, 0.04, 0.08);
    style.palettePhase = float3(0.0, 0.2, 0.45);
    style.paletteOffset = 0.1;
    style.paletteSpread = 0.3;
    style.lineGlowIntensity = 0.85;
    style.lineGlowSharpness = 260.0;
    style.haloGlowIntensity = 0.1;
    style.haloGlowSharpness = 45.0;
    return style;
}

float2 _fractal_kifs_orbit(float2 p, FractalKifsStyle style)
{
    float angle = oscillate_by_time(style.angle, style.angleAmplitude, style.angleSpeed);
    return fractal_kifs(p * style.coordinateScale, style.iterations, style.offset, angle, style.scale);
}

float3 _fractal_kifs_shade(float2 orbit, FractalKifsStyle style)
{
    float3 tint = cosine_palette(style.paletteSpread * log(orbit.y + 0.05) + style.paletteOffset, style.palettePhase);
    float glow = _fractal_exp_glow(orbit.x, style.lineGlowIntensity, style.lineGlowSharpness) + _fractal_exp_glow(orbit.x, style.haloGlowIntensity, style.haloGlowSharpness);
    return style.backgroundColor + tint * glow;
}

// in: float2 座標（[-1,1]）, FractalKifsStyle 見た目  out: float3 折り目線が光る KIFS の色（回転角が時間で揺れる）
// 推奨反復回数: 8〜12（上限 16）
float3 fractal_kifs_color(float2 p, FractalKifsStyle style)
{
    return _fractal_kifs_shade(_fractal_kifs_orbit(p, style), style);
}

// in: float2 座標（[-1,1]）, FractalKifsStyle 見た目, out float2 折り目線までの距離の座標空間での勾配（正規化しない）  out: float3 fractal_kifs_color と同じ色
// 推奨反復回数: 8〜12（上限 16）。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_kifs_color(float2 p, FractalKifsStyle style, out float2 gradient)
{
    float2 orbit = _fractal_kifs_orbit(p, style);
    gradient = screen_space_gradient(orbit.x / style.coordinateScale, p);
    return _fractal_kifs_shade(orbit, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_kifs_color
// 反復 10 回
float3 fractal_kifs_color(float2 p)
{
    return fractal_kifs_color(p, fractal_kifs_default_style());
}

// in: float2 座標（[-1,1]）, out float2 折り目線までの距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_kifs_color
// 反復 10 回。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_kifs_color(float2 p, out float2 gradient)
{
    return fractal_kifs_color(p, fractal_kifs_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalKifsStyle 見た目  out: float fractal_kifs_color が光らせる折り目線までの距離（p と同じ単位）
// 推奨反復回数: 8〜12（上限 16）
float fractal_kifs_distance(float2 p, FractalKifsStyle style)
{
    return _fractal_kifs_orbit(p, style).x / style.coordinateScale;
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_kifs_distance
// 反復 10 回
float fractal_kifs_distance(float2 p)
{
    return fractal_kifs_distance(p, fractal_kifs_default_style());
}

struct FractalKaleidoscopeRingsStyle
{
    float coordinateScale;
    float rotationSpeed;
    float segmentCount;
    int iterations;
    float2 offset;
    float angle;
    float angleAmplitude;
    float angleSpeed;
    float scale;
    float ringRadius;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float ringGlowIntensity;
    float ringGlowSharpness;
    float haloGlowIntensity;
    float haloGlowSharpness;
};

// out: FractalKaleidoscopeRingsStyle fractal_kaleidoscope_rings_color の推奨値
// 反復なし
FractalKaleidoscopeRingsStyle fractal_kaleidoscope_rings_default_style()
{
    FractalKaleidoscopeRingsStyle style;
    style.coordinateScale = 1.15;
    style.rotationSpeed = 0.05;
    style.segmentCount = 6.0;
    style.iterations = 8;
    style.offset = float2(0.42, 0.16);
    style.angle = 0.9;
    style.angleAmplitude = 0.12;
    style.angleSpeed = 0.2;
    style.scale = 1.35;
    style.ringRadius = 0.38;
    style.backgroundColor = float3(0.03, 0.03, 0.07);
    style.palettePhase = float3(0.0, 0.1, 0.2);
    style.paletteOffset = 0.62;
    style.paletteSpread = 0.35;
    style.ringGlowIntensity = 0.8;
    style.ringGlowSharpness = 240.0;
    style.haloGlowIntensity = 0.1;
    style.haloGlowSharpness = 40.0;
    return style;
}

float2 _fractal_kaleidoscope_rings_orbit(float2 p, FractalKaleidoscopeRingsStyle style)
{
    float rotation = cycle_by_time(style.rotationSpeed, 2.0 * FRACTAL_PI);
    float2 folded = fold_kaleidoscope(p * style.coordinateScale, style.segmentCount, rotation);
    float angle = oscillate_by_time(style.angle, style.angleAmplitude, style.angleSpeed);
    return fractal_kifs_rings(folded, style.iterations, style.offset, angle, style.scale, style.ringRadius);
}

float3 _fractal_kaleidoscope_rings_shade(float2 orbit, FractalKaleidoscopeRingsStyle style)
{
    float3 tint = cosine_palette(style.paletteSpread * log(orbit.y + 0.05) + style.paletteOffset, style.palettePhase);
    float glow = _fractal_exp_glow(orbit.x, style.ringGlowIntensity, style.ringGlowSharpness) + _fractal_exp_glow(orbit.x, style.haloGlowIntensity, style.haloGlowSharpness);
    return style.backgroundColor + tint * glow;
}

// in: float2 座標（[-1,1]）, FractalKaleidoscopeRingsStyle 見た目  out: float3 万華鏡で折りたたんだ KIFS の輪が光る色（全体が時間で回る）
// 推奨反復回数: 6〜10（上限 16）
float3 fractal_kaleidoscope_rings_color(float2 p, FractalKaleidoscopeRingsStyle style)
{
    return _fractal_kaleidoscope_rings_shade(_fractal_kaleidoscope_rings_orbit(p, style), style);
}

// in: float2 座標（[-1,1]）, FractalKaleidoscopeRingsStyle 見た目, out float2 輪までの距離の座標空間での勾配（正規化しない）  out: float3 fractal_kaleidoscope_rings_color と同じ色
// 推奨反復回数: 6〜10（上限 16）。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_kaleidoscope_rings_color(float2 p, FractalKaleidoscopeRingsStyle style, out float2 gradient)
{
    float2 orbit = _fractal_kaleidoscope_rings_orbit(p, style);
    gradient = screen_space_gradient(orbit.x / style.coordinateScale, p);
    return _fractal_kaleidoscope_rings_shade(orbit, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_kaleidoscope_rings_color
// 反復 8 回
float3 fractal_kaleidoscope_rings_color(float2 p)
{
    return fractal_kaleidoscope_rings_color(p, fractal_kaleidoscope_rings_default_style());
}

// in: float2 座標（[-1,1]）, out float2 輪までの距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_kaleidoscope_rings_color
// 反復 8 回。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_kaleidoscope_rings_color(float2 p, out float2 gradient)
{
    return fractal_kaleidoscope_rings_color(p, fractal_kaleidoscope_rings_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalKaleidoscopeRingsStyle 見た目  out: float fractal_kaleidoscope_rings_color が光らせる輪までの距離（p と同じ単位）
// 推奨反復回数: 6〜10（上限 16）
float fractal_kaleidoscope_rings_distance(float2 p, FractalKaleidoscopeRingsStyle style)
{
    return _fractal_kaleidoscope_rings_orbit(p, style).x / style.coordinateScale;
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_kaleidoscope_rings_distance
// 反復 8 回
float fractal_kaleidoscope_rings_distance(float2 p)
{
    return fractal_kaleidoscope_rings_distance(p, fractal_kaleidoscope_rings_default_style());
}

struct FractalKochSnowflakeStyle
{
    float coordinateScale;
    int iterations;
    float angle;
    float angleAmplitude;
    float angleSpeed;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float paletteSpeed;
    float outlineGlowIntensity;
    float outlineGlowSharpness;
    float haloGlowIntensity;
    float haloGlowSharpness;
    float ambientGlowIntensity;
    float ambientGlowSharpness;
};

// out: FractalKochSnowflakeStyle fractal_koch_snowflake_color の推奨値
// 反復なし
FractalKochSnowflakeStyle fractal_koch_snowflake_default_style()
{
    FractalKochSnowflakeStyle style;
    style.coordinateScale = 0.62;
    style.iterations = 5;
    style.angle = 0.0;
    style.angleAmplitude = 0.08;
    style.angleSpeed = 0.25;
    style.backgroundColor = float3(0.02, 0.035, 0.07);
    style.palettePhase = float3(0.0, 0.12, 0.3);
    style.paletteOffset = 0.5;
    style.paletteSpread = 0.6;
    style.paletteSpeed = 0.08;
    style.outlineGlowIntensity = 1.0;
    style.outlineGlowSharpness = 220.0;
    style.haloGlowIntensity = 0.3;
    style.haloGlowSharpness = 30.0;
    style.ambientGlowIntensity = 0.1;
    style.ambientGlowSharpness = 5.0;
    return style;
}

float2 _fractal_koch_snowflake_rotated(float2 p, FractalKochSnowflakeStyle style)
{
    return _fractal_rotate_around_origin(p, oscillate_by_time(style.angle, style.angleAmplitude, style.angleSpeed));
}

float _fractal_koch_snowflake_scaled_distance(float2 rotated, FractalKochSnowflakeStyle style)
{
    return fractal_koch_snowflake(rotated * style.coordinateScale, style.iterations);
}

float3 _fractal_koch_snowflake_shade(float2 rotated, float scaledDistanceToOutline, FractalKochSnowflakeStyle style)
{
    float3 tint = cosine_palette(style.paletteSpread * length(rotated) + cycle_by_time(style.paletteSpeed, 1.0) + style.paletteOffset, style.palettePhase);
    float glow = _fractal_exp_glow(scaledDistanceToOutline, style.outlineGlowIntensity, style.outlineGlowSharpness)
        + _fractal_exp_glow(scaledDistanceToOutline, style.haloGlowIntensity, style.haloGlowSharpness)
        + _fractal_exp_glow(scaledDistanceToOutline, style.ambientGlowIntensity, style.ambientGlowSharpness);
    return style.backgroundColor + tint * glow;
}

// in: float2 座標（[-1,1]）, FractalKochSnowflakeStyle 見た目  out: float3 輪郭が光るコッホ雪片の色（向きが時間で揺れる）
// 推奨反復回数: 4〜5（上限 6）
float3 fractal_koch_snowflake_color(float2 p, FractalKochSnowflakeStyle style)
{
    float2 rotated = _fractal_koch_snowflake_rotated(p, style);
    return _fractal_koch_snowflake_shade(rotated, _fractal_koch_snowflake_scaled_distance(rotated, style), style);
}

// in: float2 座標（[-1,1]）, FractalKochSnowflakeStyle 見た目, out float2 雪片の輪郭までの距離の座標空間での勾配（正規化しない）  out: float3 fractal_koch_snowflake_color と同じ色
// 推奨反復回数: 4〜5（上限 6）。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_koch_snowflake_color(float2 p, FractalKochSnowflakeStyle style, out float2 gradient)
{
    float2 rotated = _fractal_koch_snowflake_rotated(p, style);
    float scaledDistanceToOutline = _fractal_koch_snowflake_scaled_distance(rotated, style);
    gradient = screen_space_gradient(scaledDistanceToOutline / style.coordinateScale, p);
    return _fractal_koch_snowflake_shade(rotated, scaledDistanceToOutline, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_koch_snowflake_color
// 反復 5 回
float3 fractal_koch_snowflake_color(float2 p)
{
    return fractal_koch_snowflake_color(p, fractal_koch_snowflake_default_style());
}

// in: float2 座標（[-1,1]）, out float2 雪片の輪郭までの距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_koch_snowflake_color
// 反復 5 回。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_koch_snowflake_color(float2 p, out float2 gradient)
{
    return fractal_koch_snowflake_color(p, fractal_koch_snowflake_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalKochSnowflakeStyle 見た目  out: float fractal_koch_snowflake_color が光らせる雪片の輪郭までの距離（p と同じ単位）
// 推奨反復回数: 4〜5（上限 6）
float fractal_koch_snowflake_distance(float2 p, FractalKochSnowflakeStyle style)
{
    return _fractal_koch_snowflake_scaled_distance(_fractal_koch_snowflake_rotated(p, style), style) / style.coordinateScale;
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_koch_snowflake_distance
// 反復 5 回
float fractal_koch_snowflake_distance(float2 p)
{
    return fractal_koch_snowflake_distance(p, fractal_koch_snowflake_default_style());
}

struct FractalSierpinskiCarpetStyle
{
    float coordinateScale;
    int iterations;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float paletteSpeed;
};

// out: FractalSierpinskiCarpetStyle fractal_sierpinski_carpet_color の推奨値
// 反復なし
FractalSierpinskiCarpetStyle fractal_sierpinski_carpet_default_style()
{
    FractalSierpinskiCarpetStyle style;
    style.coordinateScale = 1.08;
    style.iterations = 5;
    style.backgroundColor = float3(0.08, 0.075, 0.15);
    style.palettePhase = float3(0.0, 0.33, 0.6);
    style.paletteOffset = 0.08;
    style.paletteSpread = 0.22;
    style.paletteSpeed = 0.05;
    return style;
}

float2 _fractal_sierpinski_carpet_scaled(float2 p, FractalSierpinskiCarpetStyle style)
{
    return p * style.coordinateScale;
}

float _fractal_sierpinski_carpet_scaled_distance(float2 scaled, FractalSierpinskiCarpetStyle style)
{
    return fractal_sierpinski_carpet(scaled, style.iterations);
}

float3 _fractal_sierpinski_carpet_shade(float2 scaled, float scaledSignedDistance, FractalSierpinskiCarpetStyle style)
{
    float smoothing = edge_smoothing_width(scaled);
    float fill = smoothstep(smoothing, -smoothing, scaledSignedDistance);
    float3 tint = cosine_palette(style.paletteSpread * (scaled.x - scaled.y) + cycle_by_time(style.paletteSpeed, 1.0) + style.paletteOffset, style.palettePhase);
    return lerp(style.backgroundColor, tint, fill);
}

// in: float2 座標（[-1,1]）, FractalSierpinskiCarpetStyle 見た目  out: float3 塗りにパレットが流れるシェルピンスキーのカーペットの色
// 推奨反復回数: 4〜5（上限 6）。fwidth を使うのでフラグメントシェーダー専用
float3 fractal_sierpinski_carpet_color(float2 p, FractalSierpinskiCarpetStyle style)
{
    float2 scaled = _fractal_sierpinski_carpet_scaled(p, style);
    return _fractal_sierpinski_carpet_shade(scaled, _fractal_sierpinski_carpet_scaled_distance(scaled, style), style);
}

// in: float2 座標（[-1,1]）, FractalSierpinskiCarpetStyle 見た目, out float2 カーペットの符号付き距離の座標空間での勾配（正規化しない）  out: float3 fractal_sierpinski_carpet_color と同じ色
// 推奨反復回数: 4〜5（上限 6）。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_sierpinski_carpet_color(float2 p, FractalSierpinskiCarpetStyle style, out float2 gradient)
{
    float2 scaled = _fractal_sierpinski_carpet_scaled(p, style);
    float scaledSignedDistance = _fractal_sierpinski_carpet_scaled_distance(scaled, style);
    gradient = screen_space_gradient(scaledSignedDistance / style.coordinateScale, p);
    return _fractal_sierpinski_carpet_shade(scaled, scaledSignedDistance, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_sierpinski_carpet_color
// 反復 5 回
float3 fractal_sierpinski_carpet_color(float2 p)
{
    return fractal_sierpinski_carpet_color(p, fractal_sierpinski_carpet_default_style());
}

// in: float2 座標（[-1,1]）, out float2 カーペットの符号付き距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_sierpinski_carpet_color
// 反復 5 回。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_sierpinski_carpet_color(float2 p, out float2 gradient)
{
    return fractal_sierpinski_carpet_color(p, fractal_sierpinski_carpet_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalSierpinskiCarpetStyle 見た目  out: float fractal_sierpinski_carpet_color が塗るカーペットの符号付き距離（内側が負。p と同じ単位）
// 推奨反復回数: 4〜5（上限 6）
float fractal_sierpinski_carpet_distance(float2 p, FractalSierpinskiCarpetStyle style)
{
    return _fractal_sierpinski_carpet_scaled_distance(_fractal_sierpinski_carpet_scaled(p, style), style) / style.coordinateScale;
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_sierpinski_carpet_distance
// 反復 5 回
float fractal_sierpinski_carpet_distance(float2 p)
{
    return fractal_sierpinski_carpet_distance(p, fractal_sierpinski_carpet_default_style());
}

struct FractalBoxFoldStyle
{
    float coordinateScale;
    int iterations;
    float foldScale;
    float foldScaleAmplitude;
    float foldScaleSpeed;
    float divergedFadeStart;
    float divergedFadeEnd;
    float divergedBrightness;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float3 axisGlowColor;
    float axisGlowIntensity;
    float axisGlowSharpness;
    float brightness;
    float3 backgroundColor;
};

// out: FractalBoxFoldStyle fractal_box_fold_color の推奨値
// 反復なし
FractalBoxFoldStyle fractal_box_fold_default_style()
{
    FractalBoxFoldStyle style;
    style.coordinateScale = 2.5;
    style.iterations = 12;
    style.foldScale = -1.75;
    style.foldScaleAmplitude = 0.08;
    style.foldScaleSpeed = 0.3;
    style.divergedFadeStart = 4.0;
    style.divergedFadeEnd = 40.0;
    style.divergedBrightness = 0.18;
    style.palettePhase = float3(0.0, 0.1, 0.22);
    style.paletteOffset = 0.58;
    style.paletteSpread = 0.16;
    style.axisGlowColor = float3(0.9, 0.95, 1.0);
    style.axisGlowIntensity = 0.45;
    style.axisGlowSharpness = 26.0;
    style.brightness = 0.92;
    style.backgroundColor = float3(0.02, 0.02, 0.04);
    return style;
}

// in: float2 座標（[-1,1]）, FractalBoxFoldStyle 見た目  out: float3 発散した所を暗くし軸付近を光らせたボックス折りの色（折りの倍率が時間で揺れる）
// 推奨反復回数: 8〜12（除算あり）
float3 fractal_box_fold_color(float2 p, FractalBoxFoldStyle style)
{
    float foldScale = oscillate_by_time(style.foldScale, style.foldScaleAmplitude, style.foldScaleSpeed);
    float3 orbit = fractal_box_fold(p * style.coordinateScale, style.iterations, foldScale);
    float bounded = 1.0 - smoothstep(style.divergedFadeStart, style.divergedFadeEnd, orbit.z);
    float3 tint = cosine_palette(style.paletteSpread * log(orbit.x + 1e-3) + style.paletteOffset, style.palettePhase);
    float3 axisGlow = style.axisGlowColor * _fractal_exp_glow(orbit.y, style.axisGlowIntensity, style.axisGlowSharpness);
    float3 lit = tint * lerp(style.divergedBrightness, 1.0, bounded) + axisGlow * bounded;
    return lit * style.brightness + style.backgroundColor;
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_box_fold_color
// 反復 12 回
float3 fractal_box_fold_color(float2 p)
{
    return fractal_box_fold_color(p, fractal_box_fold_default_style());
}

struct FractalApollonianStyle
{
    float coordinateScale;
    float driftAmplitude;
    float driftSpeed;
    int iterations;
    float strength;
    float strengthAmplitude;
    float strengthSpeed;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float baseBrightness;
    float orbitBrightness;
    float orbitBrightnessFadeDistance;
    float3 lineColor;
    float lineGlowIntensity;
    float lineGlowSharpness;
};

// out: FractalApollonianStyle fractal_apollonian_color の推奨値
// 反復なし
FractalApollonianStyle fractal_apollonian_default_style()
{
    FractalApollonianStyle style;
    style.coordinateScale = 1.15;
    style.driftAmplitude = 0.08;
    style.driftSpeed = 0.2;
    style.iterations = 8;
    style.strength = 1.18;
    style.strengthAmplitude = 0.07;
    style.strengthSpeed = 0.25;
    style.palettePhase = float3(0.0, 0.08, 0.18);
    style.paletteOffset = 0.95;
    style.paletteSpread = 0.28;
    style.baseBrightness = 0.16;
    style.orbitBrightness = 0.5;
    style.orbitBrightnessFadeDistance = 0.6;
    style.lineColor = float3(1.0, 0.92, 0.8);
    style.lineGlowIntensity = 0.8;
    style.lineGlowSharpness = 260.0;
    return style;
}

// in: float2 座標（[-1,1]）, FractalApollonianStyle 見た目  out: float3 線が光るアポロニウスのギャスケットの色（横に漂い、反転の強さが時間で揺れる）
// 推奨反復回数: 6〜8（除算あり）
float3 fractal_apollonian_color(float2 p, FractalApollonianStyle style)
{
    float2 drifted = p * style.coordinateScale + float2(oscillate_by_time(0.0, style.driftAmplitude, style.driftSpeed), 0.0);
    float strength = oscillate_by_time(style.strength, style.strengthAmplitude, style.strengthSpeed);
    float2 orbit = fractal_apollonian(drifted, style.iterations, strength);
    float3 tint = cosine_palette(style.paletteSpread * log(orbit.y + 1e-3) + style.paletteOffset, style.palettePhase);
    float brightness = style.baseBrightness + style.orbitBrightness * smoothstep(0.0, style.orbitBrightnessFadeDistance, sqrt(orbit.y));
    return tint * brightness + style.lineColor * _fractal_exp_glow(orbit.x, style.lineGlowIntensity, style.lineGlowSharpness);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_apollonian_color
// 反復 8 回
float3 fractal_apollonian_color(float2 p)
{
    return fractal_apollonian_color(p, fractal_apollonian_default_style());
}

struct FractalKaliStyle
{
    float coordinateScale;
    float2 coordinateOffset;
    int iterations;
    float2 offset;
    float2 offsetAmplitude;
    float2 offsetSpeed;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float baseBrightness;
    float glowBrightness;
    float3 coreColor;
    float coreGlowIntensity;
    float coreGlowSharpness;
};

// out: FractalKaliStyle fractal_kali_color の推奨値
// 反復なし
FractalKaliStyle fractal_kali_default_style()
{
    FractalKaliStyle style;
    style.coordinateScale = 1.25;
    style.coordinateOffset = float2(0.3, 0.15);
    style.iterations = 12;
    style.offset = float2(0.85, 0.52);
    style.offsetAmplitude = float2(0.025, 0.025);
    style.offsetSpeed = float2(0.3, 0.23);
    style.backgroundColor = float3(0.02, 0.02, 0.05);
    style.palettePhase = float3(0.0, 0.12, 0.28);
    style.paletteOffset = 0.72;
    style.paletteSpread = 0.22;
    style.baseBrightness = 0.2;
    style.glowBrightness = 2.6;
    style.coreColor = float3(1.0, 0.9, 0.8);
    style.coreGlowIntensity = 0.5;
    style.coreGlowSharpness = 9.0;
    return style;
}

// in: float2 座標（[-1,1]）, FractalKaliStyle 見た目  out: float3 Kali セットの色（毎回引く定数が時間で揺れる）
// 推奨反復回数: 8〜12（除算と exp あり）
float3 fractal_kali_color(float2 p, FractalKaliStyle style)
{
    float2 offset = float2(
        oscillate_by_time(style.offset.x, style.offsetAmplitude.x, style.offsetSpeed.x),
        oscillate_by_time(style.offset.y, style.offsetAmplitude.y, style.offsetSpeed.y));
    float2 orbit = fractal_kali(p * style.coordinateScale + style.coordinateOffset, style.iterations, offset);
    float3 tint = cosine_palette(style.paletteSpread * log(orbit.y + 1e-3) + style.paletteOffset, style.palettePhase);
    float brightness = style.baseBrightness + style.glowBrightness * orbit.x * orbit.x;
    return style.backgroundColor + tint * brightness + style.coreColor * _fractal_exp_glow(orbit.y, style.coreGlowIntensity, style.coreGlowSharpness);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_kali_color
// 反復 12 回
float3 fractal_kali_color(float2 p)
{
    return fractal_kali_color(p, fractal_kali_default_style());
}

static const int FRACTAL_GLOW_RINGS_ITERATIONS = 4;
static const float FRACTAL_GLOW_RINGS_RING_SPEED = 0.6;
static const float FRACTAL_GLOW_RINGS_PALETTE_SPEED = 0.12;
static const float3 FRACTAL_GLOW_RINGS_PALETTE_PHASE = float3(0.263, 0.416, 0.557);

// in: float2 座標（[-1,1]）, int 反復回数, float 輪の位相の角速度（rad/s）, float パレットが 1 秒に進む量, float3 パレットの位相  out: float3 輪が時間で波打つ fractal_glow_rings の色
// 推奨反復回数: 3〜4（sin・pow・exp あり。上限 6）
float3 fractal_glow_rings_color(float2 p, int iterations, float ringSpeed, float paletteSpeed, float3 palettePhase)
{
    return fractal_glow_rings(p, iterations, cycle_by_time(ringSpeed, 2.0 * FRACTAL_PI), cycle_by_time(paletteSpeed, 1.0), palettePhase);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_glow_rings_color
// 反復 4 回
float3 fractal_glow_rings_color(float2 p)
{
    return fractal_glow_rings_color(p, FRACTAL_GLOW_RINGS_ITERATIONS, FRACTAL_GLOW_RINGS_RING_SPEED, FRACTAL_GLOW_RINGS_PALETTE_SPEED, FRACTAL_GLOW_RINGS_PALETTE_PHASE);
}

static const float2 FRACTAL_SIERPINSKI_TRIANGLE_TOP_VERTEX = float2(0.0, 1.0);
static const float FRACTAL_SIERPINSKI_TRIANGLE_ZOOM_PER_LOOP = 2.0;
static const float2 FRACTAL_SIERPINSKI_CARPET_ZOOM_CENTER = float2(0.5, 0.5);
static const float FRACTAL_SIERPINSKI_CARPET_ZOOM_PER_LOOP = 9.0;
static const float FRACTAL_SIERPINSKI_CARPET_LEVELS_PER_LOOP = 2.0;
static const float2 FRACTAL_KOCH_SNOWFLAKE_TIP = float2(0.5, 0.2886751);
static const float FRACTAL_KOCH_SNOWFLAKE_ZOOM_PER_LOOP = 3.0;

float _fractal_zoomed_units_per_screen_unit(float coordinateScale, float zoomPerLoop, float progress)
{
    return coordinateScale * zoom_loop_scale(zoomPerLoop, progress);
}

float _fractal_zoom_blended_distance(float2 coarseAndFineDistance, float fineWeight, float zoomedUnitsPerScreenUnit)
{
    return lerp(coarseAndFineDistance.x, coarseAndFineDistance.y, fineWeight) / zoomedUnitsPerScreenUnit;
}

struct FractalZoomSierpinskiTriangleStyle
{
    float2 zoomCenterOnScreen;
    float coordinateScale;
    float secondsPerLoop;
    int iterations;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteWaveAmplitude;
    float paletteWaveCount;
    float glowIntensity;
    float glowSharpness;
};

// out: FractalZoomSierpinskiTriangleStyle fractal_zoom_sierpinski_triangle_color の推奨値
// 反復なし
FractalZoomSierpinskiTriangleStyle fractal_zoom_sierpinski_triangle_default_style()
{
    FractalZoomSierpinskiTriangleStyle style;
    style.zoomCenterOnScreen = float2(0.0, 0.714);
    style.coordinateScale = 0.8;
    style.secondsPerLoop = 8.0;
    style.iterations = 6;
    style.backgroundColor = float3(0.03, 0.035, 0.07);
    style.palettePhase = float3(0.0, 0.15, 0.35);
    style.paletteWaveAmplitude = 0.25;
    style.paletteWaveCount = 3.0;
    style.glowIntensity = 0.55;
    style.glowSharpness = 35.0;
    return style;
}

float _fractal_zoom_sierpinski_triangle_progress(FractalZoomSierpinskiTriangleStyle style)
{
    return _Time.y / style.secondsPerLoop;
}

float2 _fractal_zoom_sierpinski_triangle_zoomed(float2 p, float progress, FractalZoomSierpinskiTriangleStyle style)
{
    float2 topVertex = FRACTAL_SIERPINSKI_TRIANGLE_TOP_VERTEX;
    return zoom_loop(topVertex + (p - style.zoomCenterOnScreen) * style.coordinateScale, topVertex, FRACTAL_SIERPINSKI_TRIANGLE_ZOOM_PER_LOOP, progress);
}

float _fractal_zoom_sierpinski_triangle_zoomed_per_screen(float progress, FractalZoomSierpinskiTriangleStyle style)
{
    return _fractal_zoomed_units_per_screen_unit(style.coordinateScale, FRACTAL_SIERPINSKI_TRIANGLE_ZOOM_PER_LOOP, progress);
}

float2 _fractal_zoom_sierpinski_triangle_layer_distances(float2 zoomed, FractalZoomSierpinskiTriangleStyle style)
{
    return float2(fractal_sierpinski_triangle(zoomed, style.iterations), fractal_sierpinski_triangle(zoomed, style.iterations + 1));
}

float3 _fractal_zoom_sierpinski_triangle_layer_shade(float distanceToTriangle, float3 tint, float smoothing, float zoomedPerScreen, FractalZoomSierpinskiTriangleStyle style)
{
    float fill = smoothstep(smoothing, -smoothing, distanceToTriangle);
    float glow = _fractal_exp_glow(max(distanceToTriangle, 0.0) / zoomedPerScreen, style.glowIntensity, style.glowSharpness);
    return lerp(style.backgroundColor + tint * glow, tint, fill);
}

float3 _fractal_zoom_sierpinski_triangle_shade(float2 zoomed, float2 layerDistances, float progress, FractalZoomSierpinskiTriangleStyle style)
{
    float smoothing = edge_smoothing_width(zoomed);
    float zoomedPerScreen = _fractal_zoom_sierpinski_triangle_zoomed_per_screen(progress, style);
    float2 fromTop = zoomed - FRACTAL_SIERPINSKI_TRIANGLE_TOP_VERTEX;
    float hue = log2(length(fromTop) + 1e-4) + style.paletteWaveAmplitude * sin(style.paletteWaveCount * atan2(fromTop.x, -fromTop.y));
    float3 tint = cosine_palette(hue, style.palettePhase);
    float3 coarse = _fractal_zoom_sierpinski_triangle_layer_shade(layerDistances.x, tint, smoothing, zoomedPerScreen, style);
    float3 fine = _fractal_zoom_sierpinski_triangle_layer_shade(layerDistances.y, tint, smoothing, zoomedPerScreen, style);
    return lerp(coarse, fine, frac(progress));
}

float _fractal_zoom_sierpinski_triangle_blended_distance(float2 layerDistances, float progress, FractalZoomSierpinskiTriangleStyle style)
{
    return _fractal_zoom_blended_distance(layerDistances, frac(progress), _fractal_zoom_sierpinski_triangle_zoomed_per_screen(progress, style));
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiTriangleStyle 見た目  out: float3 上の頂点へ無限に拡大し続けるシェルピンスキーの三角形の色
// 推奨反復回数: 6〜7（1 段深い反復も合わせて評価する。上限 9）。fwidth を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_triangle_color(float2 p, FractalZoomSierpinskiTriangleStyle style)
{
    float progress = _fractal_zoom_sierpinski_triangle_progress(style);
    float2 zoomed = _fractal_zoom_sierpinski_triangle_zoomed(p, progress, style);
    return _fractal_zoom_sierpinski_triangle_shade(zoomed, _fractal_zoom_sierpinski_triangle_layer_distances(zoomed, style), progress, style);
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiTriangleStyle 見た目, out float2 2 段の符号付き距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 fractal_zoom_sierpinski_triangle_color と同じ色
// 推奨反復回数: 6〜7（1 段深い反復も合わせて評価する。上限 9）。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_triangle_color(float2 p, FractalZoomSierpinskiTriangleStyle style, out float2 gradient)
{
    float progress = _fractal_zoom_sierpinski_triangle_progress(style);
    float2 zoomed = _fractal_zoom_sierpinski_triangle_zoomed(p, progress, style);
    float2 layerDistances = _fractal_zoom_sierpinski_triangle_layer_distances(zoomed, style);
    gradient = screen_space_gradient(_fractal_zoom_sierpinski_triangle_blended_distance(layerDistances, progress, style), p);
    return _fractal_zoom_sierpinski_triangle_shade(zoomed, layerDistances, progress, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_zoom_sierpinski_triangle_color
// 反復 6 回と 7 回
float3 fractal_zoom_sierpinski_triangle_color(float2 p)
{
    return fractal_zoom_sierpinski_triangle_color(p, fractal_zoom_sierpinski_triangle_default_style());
}

// in: float2 座標（[-1,1]）, out float2 2 段の符号付き距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_zoom_sierpinski_triangle_color
// 反復 6 回と 7 回。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_triangle_color(float2 p, out float2 gradient)
{
    return fractal_zoom_sierpinski_triangle_color(p, fractal_zoom_sierpinski_triangle_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiTriangleStyle 見た目  out: float 反復回数の違う 2 段の符号付き距離を、色と同じ重みで混ぜた値（内側が負。p と同じ単位）
// 推奨反復回数: 6〜7（1 段深い反復も合わせて評価する。上限 9）
float fractal_zoom_sierpinski_triangle_distance(float2 p, FractalZoomSierpinskiTriangleStyle style)
{
    float progress = _fractal_zoom_sierpinski_triangle_progress(style);
    float2 zoomed = _fractal_zoom_sierpinski_triangle_zoomed(p, progress, style);
    return _fractal_zoom_sierpinski_triangle_blended_distance(_fractal_zoom_sierpinski_triangle_layer_distances(zoomed, style), progress, style);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_zoom_sierpinski_triangle_distance
// 反復 6 回と 7 回
float fractal_zoom_sierpinski_triangle_distance(float2 p)
{
    return fractal_zoom_sierpinski_triangle_distance(p, fractal_zoom_sierpinski_triangle_default_style());
}

struct FractalZoomSierpinskiCarpetStyle
{
    float coordinateScale;
    float secondsPerLoop;
    int iterations;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float paletteSpeed;
};

// out: FractalZoomSierpinskiCarpetStyle fractal_zoom_sierpinski_carpet_color の推奨値
// 反復なし
FractalZoomSierpinskiCarpetStyle fractal_zoom_sierpinski_carpet_default_style()
{
    FractalZoomSierpinskiCarpetStyle style;
    style.coordinateScale = 0.45;
    style.secondsPerLoop = 25.0;
    style.iterations = 4;
    style.backgroundColor = float3(0.08, 0.075, 0.15);
    style.palettePhase = float3(0.0, 0.33, 0.6);
    style.paletteOffset = 0.08;
    style.paletteSpread = 0.22;
    style.paletteSpeed = 0.05;
    return style;
}

float _fractal_zoom_sierpinski_carpet_progress(FractalZoomSierpinskiCarpetStyle style)
{
    return _Time.y / style.secondsPerLoop;
}

float _fractal_zoom_sierpinski_carpet_level(float progress)
{
    return FRACTAL_SIERPINSKI_CARPET_LEVELS_PER_LOOP * frac(progress);
}

float2 _fractal_zoom_sierpinski_carpet_zoomed(float2 p, float progress, FractalZoomSierpinskiCarpetStyle style)
{
    float2 zoomCenter = FRACTAL_SIERPINSKI_CARPET_ZOOM_CENTER;
    return zoom_loop(zoomCenter + p * style.coordinateScale, zoomCenter, FRACTAL_SIERPINSKI_CARPET_ZOOM_PER_LOOP, progress);
}

float2 _fractal_zoom_sierpinski_carpet_layer_distances(float2 zoomed, float level, FractalZoomSierpinskiCarpetStyle style)
{
    int iterations = style.iterations + (int)level;
    return float2(fractal_sierpinski_carpet(zoomed, iterations), fractal_sierpinski_carpet(zoomed, iterations + 1));
}

float3 _fractal_zoom_sierpinski_carpet_shade(float2 p, float2 zoomed, float2 layerDistances, float level, FractalZoomSierpinskiCarpetStyle style)
{
    float smoothing = edge_smoothing_width(zoomed);
    float coarseFill = smoothstep(smoothing, -smoothing, layerDistances.x);
    float fineFill = smoothstep(smoothing, -smoothing, layerDistances.y);
    float3 tint = cosine_palette(style.paletteSpread * (p.x - p.y) + cycle_by_time(style.paletteSpeed, 1.0) + style.paletteOffset, style.palettePhase);
    return lerp(style.backgroundColor, tint, lerp(coarseFill, fineFill, frac(level)));
}

float _fractal_zoom_sierpinski_carpet_blended_distance(float2 layerDistances, float progress, float level, FractalZoomSierpinskiCarpetStyle style)
{
    float zoomedPerScreen = _fractal_zoomed_units_per_screen_unit(style.coordinateScale, FRACTAL_SIERPINSKI_CARPET_ZOOM_PER_LOOP, progress);
    return _fractal_zoom_blended_distance(layerDistances, frac(level), zoomedPerScreen);
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiCarpetStyle 見た目  out: float3 (0.5, 0.5) へ無限に拡大し続けるシェルピンスキーのカーペットの色
// 推奨反復回数: 4（1〜2 段深い反復も評価する。上限 4）。fwidth を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_carpet_color(float2 p, FractalZoomSierpinskiCarpetStyle style)
{
    float progress = _fractal_zoom_sierpinski_carpet_progress(style);
    float level = _fractal_zoom_sierpinski_carpet_level(progress);
    float2 zoomed = _fractal_zoom_sierpinski_carpet_zoomed(p, progress, style);
    return _fractal_zoom_sierpinski_carpet_shade(p, zoomed, _fractal_zoom_sierpinski_carpet_layer_distances(zoomed, level, style), level, style);
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiCarpetStyle 見た目, out float2 2 段の符号付き距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 fractal_zoom_sierpinski_carpet_color と同じ色
// 推奨反復回数: 4（1〜2 段深い反復も評価する。上限 4）。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_carpet_color(float2 p, FractalZoomSierpinskiCarpetStyle style, out float2 gradient)
{
    float progress = _fractal_zoom_sierpinski_carpet_progress(style);
    float level = _fractal_zoom_sierpinski_carpet_level(progress);
    float2 zoomed = _fractal_zoom_sierpinski_carpet_zoomed(p, progress, style);
    float2 layerDistances = _fractal_zoom_sierpinski_carpet_layer_distances(zoomed, level, style);
    gradient = screen_space_gradient(_fractal_zoom_sierpinski_carpet_blended_distance(layerDistances, progress, level, style), p);
    return _fractal_zoom_sierpinski_carpet_shade(p, zoomed, layerDistances, level, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_zoom_sierpinski_carpet_color
// 反復 4〜6 回
float3 fractal_zoom_sierpinski_carpet_color(float2 p)
{
    return fractal_zoom_sierpinski_carpet_color(p, fractal_zoom_sierpinski_carpet_default_style());
}

// in: float2 座標（[-1,1]）, out float2 2 段の符号付き距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_zoom_sierpinski_carpet_color
// 反復 4〜6 回。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_sierpinski_carpet_color(float2 p, out float2 gradient)
{
    return fractal_zoom_sierpinski_carpet_color(p, fractal_zoom_sierpinski_carpet_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalZoomSierpinskiCarpetStyle 見た目  out: float 反復回数の違う 2 段の符号付き距離を、色と同じ重みで混ぜた値（内側が負。p と同じ単位）
// 推奨反復回数: 4（1〜2 段深い反復も評価する。上限 4）
float fractal_zoom_sierpinski_carpet_distance(float2 p, FractalZoomSierpinskiCarpetStyle style)
{
    float progress = _fractal_zoom_sierpinski_carpet_progress(style);
    float level = _fractal_zoom_sierpinski_carpet_level(progress);
    float2 zoomed = _fractal_zoom_sierpinski_carpet_zoomed(p, progress, style);
    return _fractal_zoom_sierpinski_carpet_blended_distance(_fractal_zoom_sierpinski_carpet_layer_distances(zoomed, level, style), progress, level, style);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_zoom_sierpinski_carpet_distance
// 反復 4〜6 回
float fractal_zoom_sierpinski_carpet_distance(float2 p)
{
    return fractal_zoom_sierpinski_carpet_distance(p, fractal_zoom_sierpinski_carpet_default_style());
}

struct FractalZoomKochSnowflakeStyle
{
    float2 zoomCenterOnScreen;
    float coordinateScale;
    float secondsPerLoop;
    int iterations;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float paletteSpeed;
    float outlineGlowIntensity;
    float outlineGlowSharpness;
    float haloGlowIntensity;
    float haloGlowSharpness;
    float ambientGlowIntensity;
    float ambientGlowSharpness;
};

// out: FractalZoomKochSnowflakeStyle fractal_zoom_koch_snowflake_color の推奨値。光の鋭さは画面座標の単位
// 反復なし
FractalZoomKochSnowflakeStyle fractal_zoom_koch_snowflake_default_style()
{
    FractalZoomKochSnowflakeStyle style;
    style.zoomCenterOnScreen = float2(0.55, 0.45);
    style.coordinateScale = 0.29;
    style.secondsPerLoop = 12.5;
    style.iterations = 5;
    style.backgroundColor = float3(0.02, 0.035, 0.07);
    style.palettePhase = float3(0.0, 0.12, 0.3);
    style.paletteOffset = 0.5;
    style.paletteSpread = 0.6;
    style.paletteSpeed = 0.08;
    style.outlineGlowIntensity = 1.0;
    style.outlineGlowSharpness = 140.0;
    style.haloGlowIntensity = 0.3;
    style.haloGlowSharpness = 19.0;
    style.ambientGlowIntensity = 0.1;
    style.ambientGlowSharpness = 3.0;
    return style;
}

float _fractal_zoom_koch_outline_glow(float distanceOnScreen, FractalZoomKochSnowflakeStyle style)
{
    return _fractal_exp_glow(distanceOnScreen, style.outlineGlowIntensity, style.outlineGlowSharpness)
        + _fractal_exp_glow(distanceOnScreen, style.haloGlowIntensity, style.haloGlowSharpness)
        + _fractal_exp_glow(distanceOnScreen, style.ambientGlowIntensity, style.ambientGlowSharpness);
}

float _fractal_zoom_koch_snowflake_progress(FractalZoomKochSnowflakeStyle style)
{
    return _Time.y / style.secondsPerLoop;
}

float2 _fractal_zoom_koch_snowflake_layer_distances_on_screen(float2 p, float progress, FractalZoomKochSnowflakeStyle style)
{
    float2 tip = FRACTAL_KOCH_SNOWFLAKE_TIP;
    float2 zoomed = zoom_loop(tip + (p - style.zoomCenterOnScreen) * style.coordinateScale, tip, FRACTAL_KOCH_SNOWFLAKE_ZOOM_PER_LOOP, progress);
    float zoomedPerScreen = _fractal_zoomed_units_per_screen_unit(style.coordinateScale, FRACTAL_KOCH_SNOWFLAKE_ZOOM_PER_LOOP, progress);
    return float2(fractal_koch_snowflake(zoomed, style.iterations), fractal_koch_snowflake(zoomed, style.iterations + 1)) / zoomedPerScreen;
}

float3 _fractal_zoom_koch_snowflake_shade(float2 p, float2 layerDistancesOnScreen, float progress, FractalZoomKochSnowflakeStyle style)
{
    float coarseGlow = _fractal_zoom_koch_outline_glow(layerDistancesOnScreen.x, style);
    float fineGlow = _fractal_zoom_koch_outline_glow(layerDistancesOnScreen.y, style);
    float3 tint = cosine_palette(style.paletteSpread * length(p - style.zoomCenterOnScreen) + cycle_by_time(style.paletteSpeed, 1.0) + style.paletteOffset, style.palettePhase);
    return style.backgroundColor + tint * lerp(coarseGlow, fineGlow, frac(progress));
}

float _fractal_zoom_koch_snowflake_blended_distance(float2 layerDistancesOnScreen, float progress)
{
    return lerp(layerDistancesOnScreen.x, layerDistancesOnScreen.y, frac(progress));
}

// in: float2 座標（[-1,1]）, FractalZoomKochSnowflakeStyle 見た目  out: float3 右上の先端へ無限に拡大し続けるコッホ雪片の色
// 推奨反復回数: 4〜5（1 段深い反復も合わせて評価する。上限 5）
float3 fractal_zoom_koch_snowflake_color(float2 p, FractalZoomKochSnowflakeStyle style)
{
    float progress = _fractal_zoom_koch_snowflake_progress(style);
    return _fractal_zoom_koch_snowflake_shade(p, _fractal_zoom_koch_snowflake_layer_distances_on_screen(p, progress, style), progress, style);
}

// in: float2 座標（[-1,1]）, FractalZoomKochSnowflakeStyle 見た目, out float2 2 段の輪郭までの距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 fractal_zoom_koch_snowflake_color と同じ色
// 推奨反復回数: 4〜5（1 段深い反復も合わせて評価する。上限 5）。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_koch_snowflake_color(float2 p, FractalZoomKochSnowflakeStyle style, out float2 gradient)
{
    float progress = _fractal_zoom_koch_snowflake_progress(style);
    float2 layerDistancesOnScreen = _fractal_zoom_koch_snowflake_layer_distances_on_screen(p, progress, style);
    gradient = screen_space_gradient(_fractal_zoom_koch_snowflake_blended_distance(layerDistancesOnScreen, progress), p);
    return _fractal_zoom_koch_snowflake_shade(p, layerDistancesOnScreen, progress, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_zoom_koch_snowflake_color
// 反復 5 回と 6 回
float3 fractal_zoom_koch_snowflake_color(float2 p)
{
    return fractal_zoom_koch_snowflake_color(p, fractal_zoom_koch_snowflake_default_style());
}

// in: float2 座標（[-1,1]）, out float2 2 段の輪郭までの距離を混ぜた値の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_zoom_koch_snowflake_color
// 反復 5 回と 6 回。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_zoom_koch_snowflake_color(float2 p, out float2 gradient)
{
    return fractal_zoom_koch_snowflake_color(p, fractal_zoom_koch_snowflake_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalZoomKochSnowflakeStyle 見た目  out: float 反復回数の違う 2 段の輪郭までの距離を、色と同じ重みで混ぜた値（p と同じ単位）
// 推奨反復回数: 4〜5（1 段深い反復も合わせて評価する。上限 5）
float fractal_zoom_koch_snowflake_distance(float2 p, FractalZoomKochSnowflakeStyle style)
{
    float progress = _fractal_zoom_koch_snowflake_progress(style);
    return _fractal_zoom_koch_snowflake_blended_distance(_fractal_zoom_koch_snowflake_layer_distances_on_screen(p, progress, style), progress);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_zoom_koch_snowflake_distance
// 反復 5 回と 6 回
float fractal_zoom_koch_snowflake_distance(float2 p)
{
    return fractal_zoom_koch_snowflake_distance(p, fractal_zoom_koch_snowflake_default_style());
}

struct FractalLogSpiralStyle
{
    float2 target;
    float growthPerQuarterTurn;
    float armCount;
    float rotationSpeed;
    float lineWidth;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteOffset;
    float paletteSpread;
    float centerFadeInnerRadius;
    float centerFadeOuterRadius;
};

// out: FractalLogSpiralStyle fractal_log_spiral_color の推奨値（黄金らせん 1 本）。腕の本数は整数値、線の太さは p と同じ単位
// 反復なし
FractalLogSpiralStyle fractal_log_spiral_default_style()
{
    FractalLogSpiralStyle style;
    style.target = float2(0.0, 0.0);
    style.growthPerQuarterTurn = FRACTAL_GOLDEN_RATIO;
    style.armCount = 1.0;
    style.rotationSpeed = 0.5;
    style.lineWidth = 0.012;
    style.backgroundColor = float3(0.03, 0.035, 0.07);
    style.palettePhase = float3(0.0, 0.12, 0.3);
    style.paletteOffset = 0.1;
    style.paletteSpread = 0.25;
    style.centerFadeInnerRadius = 0.004;
    style.centerFadeOuterRadius = 0.03;
    return style;
}

float _fractal_log_spiral_distance(float2 p, FractalLogSpiralStyle style)
{
    float2 coord = log_spiral_coord(p, style.target, style.growthPerQuarterTurn);
    coord.y -= cycle_by_time(style.rotationSpeed, 2.0 * FRACTAL_PI) / (2.0 * FRACTAL_PI);
    float armCount = max(round(style.armCount), 1.0);
    float logRadiusToLine = log_spiral_line_distance(coord * armCount, style.growthPerQuarterTurn) / armCount;
    float logRadiusPerRadian = 2.0 * log(style.growthPerQuarterTurn) / FRACTAL_PI;
    return logRadiusToLine * length(p - style.target) / sqrt(1.0 + logRadiusPerRadian * logRadiusPerRadian);
}

float3 _fractal_log_spiral_shade(float2 p, float distanceToLine, FractalLogSpiralStyle style)
{
    float halfWidth = 0.5 * style.lineWidth;
    float smoothing = edge_smoothing_width(p);
    float lineCoverage = smoothstep(halfWidth + smoothing, halfWidth - smoothing, distanceToLine);
    float radius = length(p - style.target);
    float3 tint = cosine_palette(style.paletteSpread * log(max(radius, 1e-5)) + style.paletteOffset, style.palettePhase);
    float3 shaded = lerp(style.backgroundColor, tint, lineCoverage);
    return lerp(style.backgroundColor, shaded, smoothstep(style.centerFadeInnerRadius, style.centerFadeOuterRadius, radius));
}

// in: float2 座標（[-1,1]）, FractalLogSpiralStyle 見た目  out: float3 収束点のまわりを回る対数らせんの線の色（画面上でほぼ一定の太さ）
// 反復なし。fwidth を使うのでフラグメントシェーダー専用
float3 fractal_log_spiral_color(float2 p, FractalLogSpiralStyle style)
{
    return _fractal_log_spiral_shade(p, _fractal_log_spiral_distance(p, style), style);
}

// in: float2 座標（[-1,1]）, FractalLogSpiralStyle 見た目, out float2 らせんの線までの距離の座標空間での勾配（正規化しない）  out: float3 fractal_log_spiral_color と同じ色
// 反復なし。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_log_spiral_color(float2 p, FractalLogSpiralStyle style, out float2 gradient)
{
    float distanceToLine = _fractal_log_spiral_distance(p, style);
    gradient = screen_space_gradient(distanceToLine, p);
    return _fractal_log_spiral_shade(p, distanceToLine, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_log_spiral_color
// 反復なし。fwidth を使うのでフラグメントシェーダー専用
float3 fractal_log_spiral_color(float2 p)
{
    return fractal_log_spiral_color(p, fractal_log_spiral_default_style());
}

// in: float2 座標（[-1,1]）, out float2 らせんの線までの距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_log_spiral_color
// 反復なし。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_log_spiral_color(float2 p, out float2 gradient)
{
    return fractal_log_spiral_color(p, fractal_log_spiral_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalLogSpiralStyle 見た目  out: float fractal_log_spiral_color が描くらせんの線（中心線）までの距離（p と同じ単位。線の近くで正確な 1 次近似）
// 反復なし
float fractal_log_spiral_distance(float2 p, FractalLogSpiralStyle style)
{
    return _fractal_log_spiral_distance(p, style);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_log_spiral_distance
// 反復なし
float fractal_log_spiral_distance(float2 p)
{
    return fractal_log_spiral_distance(p, fractal_log_spiral_default_style());
}

struct FractalSpiralKifsStyle
{
    float2 target;
    float flowSpeed;
    float tilesPerUnit;
    float tileCoordinateScale;
    int iterations;
    float2 offset;
    float angle;
    float angleAmplitude;
    float angleSpeed;
    float scale;
    float3 backgroundColor;
    float3 palettePhase;
    float paletteAngleSpread;
    float paletteSpread;
    float lineGlowIntensity;
    float lineGlowSharpness;
    float haloGlowIntensity;
    float haloGlowSharpness;
    float centerFadeInnerRadius;
    float centerFadeOuterRadius;
};

// out: FractalSpiralKifsStyle fractal_spiral_kifs_color の推奨値
// 反復なし
FractalSpiralKifsStyle fractal_spiral_kifs_default_style()
{
    FractalSpiralKifsStyle style;
    style.target = float2(-0.2, 0.1);
    style.flowSpeed = 0.03;
    style.tilesPerUnit = 2.0;
    style.tileCoordinateScale = 2.6;
    style.iterations = 6;
    style.offset = float2(0.5, 0.28);
    style.angle = 0.62;
    style.angleAmplitude = 0.1;
    style.angleSpeed = 0.3;
    style.scale = 1.5;
    style.backgroundColor = float3(0.03, 0.04, 0.08);
    style.palettePhase = float3(0.0, 0.2, 0.45);
    style.paletteAngleSpread = 0.25;
    style.paletteSpread = 0.3;
    style.lineGlowIntensity = 0.85;
    style.lineGlowSharpness = 45.0;
    style.haloGlowIntensity = 0.12;
    style.haloGlowSharpness = 9.0;
    style.centerFadeInnerRadius = 0.004;
    style.centerFadeOuterRadius = 0.06;
    return style;
}

float2 _fractal_spiral_kifs_coord(float2 p, FractalSpiralKifsStyle style)
{
    float2 coord = golden_spiral_coord(p, style.target);
    coord.y += cycle_by_time(style.flowSpeed, 1.0);
    return coord;
}

float2 _fractal_spiral_kifs_orbit(float2 coord, FractalSpiralKifsStyle style)
{
    float2 tile = spiral_tile(coord, style.tilesPerUnit) * style.tileCoordinateScale;
    float angle = oscillate_by_time(style.angle, style.angleAmplitude, style.angleSpeed);
    return fractal_kifs(tile, style.iterations, style.offset, angle, style.scale);
}

float3 _fractal_spiral_kifs_shade(float2 p, float2 coord, float2 orbit, FractalSpiralKifsStyle style)
{
    float3 tint = cosine_palette(coord.y + style.paletteAngleSpread * coord.x + style.paletteSpread * log(orbit.y + 0.05), style.palettePhase);
    float glow = _fractal_exp_glow(orbit.x, style.lineGlowIntensity, style.lineGlowSharpness) + _fractal_exp_glow(orbit.x, style.haloGlowIntensity, style.haloGlowSharpness);
    float3 shaded = style.backgroundColor + tint * glow;
    return lerp(style.backgroundColor, shaded, smoothstep(style.centerFadeInnerRadius, style.centerFadeOuterRadius, length(p - style.target)));
}

float _fractal_spiral_kifs_distance_on_screen(float2 p, float2 orbit, FractalSpiralKifsStyle style)
{
    float screenUnitsPerTileUnit = _fractal_log_spiral_coord_unit_length(p, style.target, FRACTAL_GOLDEN_RATIO) / (style.tilesPerUnit * style.tileCoordinateScale);
    return orbit.x * screenUnitsPerTileUnit;
}

// in: float2 座標（[-1,1]）, FractalSpiralKifsStyle 見た目  out: float3 黄金らせんのタイルごとに KIFS を描き、収束点へ流れ込む色
// 推奨反復回数: 6（タイルごとに評価する。上限 16）
float3 fractal_spiral_kifs_color(float2 p, FractalSpiralKifsStyle style)
{
    float2 coord = _fractal_spiral_kifs_coord(p, style);
    return _fractal_spiral_kifs_shade(p, coord, _fractal_spiral_kifs_orbit(coord, style), style);
}

// in: float2 座標（[-1,1]）, FractalSpiralKifsStyle 見た目, out float2 折り目線までの距離の座標空間での勾配（正規化しない）  out: float3 fractal_spiral_kifs_color と同じ色
// 推奨反復回数: 6（タイルごとに評価する。上限 16）。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_spiral_kifs_color(float2 p, FractalSpiralKifsStyle style, out float2 gradient)
{
    float2 coord = _fractal_spiral_kifs_coord(p, style);
    float2 orbit = _fractal_spiral_kifs_orbit(coord, style);
    gradient = screen_space_gradient(_fractal_spiral_kifs_distance_on_screen(p, orbit, style), p);
    return _fractal_spiral_kifs_shade(p, coord, orbit, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた fractal_spiral_kifs_color
// 反復 6 回
float3 fractal_spiral_kifs_color(float2 p)
{
    return fractal_spiral_kifs_color(p, fractal_spiral_kifs_default_style());
}

// in: float2 座標（[-1,1]）, out float2 折り目線までの距離の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた fractal_spiral_kifs_color
// 反復 6 回。ddx/ddy を使うのでフラグメントシェーダー専用
float3 fractal_spiral_kifs_color(float2 p, out float2 gradient)
{
    return fractal_spiral_kifs_color(p, fractal_spiral_kifs_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, FractalSpiralKifsStyle 見た目  out: float fractal_spiral_kifs_color が光らせる折り目線までの距離（p と同じ単位。らせん座標の歪みを等方とみなした近似）
// 推奨反復回数: 6（タイルごとに評価する。上限 16）
float fractal_spiral_kifs_distance(float2 p, FractalSpiralKifsStyle style)
{
    return _fractal_spiral_kifs_distance_on_screen(p, _fractal_spiral_kifs_orbit(_fractal_spiral_kifs_coord(p, style), style), style);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での fractal_spiral_kifs_distance
// 反復 6 回
float fractal_spiral_kifs_distance(float2 p)
{
    return fractal_spiral_kifs_distance(p, fractal_spiral_kifs_default_style());
}

#endif
