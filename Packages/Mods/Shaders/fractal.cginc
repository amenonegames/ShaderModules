#ifndef AMENONE_FRACTAL_INCLUEDED
#define AMENONE_FRACTAL_INCLUEDED
// 推奨反復回数は Switch(初代) 全画面 60fps を想定した見積もりで、実測値ではない。上限は 720p で細部が 1 ピクセル未満になる回数
static const float FRACTAL_PI = 3.14159265358979;
static const float FRACTAL_SQRT3 = 1.7320508;
static const float FRACTAL_GOLDEN_RATIO = 1.6180339887;

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

// in: float2 座標, float2 ズームの中心, float 1 周あたりの拡大率, float 進み具合（1 で 1 周）  out: float2 中心へ拡大した座標。進み具合の整数部は無視するので、自己相似な中心と倍率を渡すと継ぎ目なく繰り返す
// 反復なし
float2 zoom_loop(float2 p, float2 center, float zoomPerLoop, float progress)
{
    return center + (p - center) * pow(zoomPerLoop, -frac(progress));
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
    return abs(frac(spiralCoord.y + 0.5) - 0.5) * 4.0 * log(growthPerQuarterTurn);
}

#endif
