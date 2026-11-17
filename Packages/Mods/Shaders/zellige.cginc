#ifndef AMENONE_ZELLIGE_INCLUEDED
#define AMENONE_ZELLIGE_INCLUEDED
#include "Packages/com.amenone.shadermodules/Shaders/fractal.cginc"

static const float ZELLIGE_INV_SQRT2 = 0.70710678;
static const float2 ZELLIGE_EDGE_MIDPOINT = float2(0.5, 0.0);

struct ZelligePattern
{
    float lineDistance;
    float cornerSide;
    float starDistance;
    float2 cellId;
    float2 cornerId;
};

float _zellige_square_distance(float2 p, float halfSize)
{
    float2 q = abs(p) - halfSize;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

float _zellige_segment_distance(float2 p, float2 a, float2 b)
{
    float2 ab = b - a;
    float t = saturate(dot(p - a, ab) / dot(ab, ab));
    return length(p - a - ab * t);
}

float _zellige_clamp_contact_angle(float contactAngle)
{
    return clamp(contactAngle, 0.0, FRACTAL_PI / 2.0);
}

// 辺中点 (0.5, 0) から角度 contactAngle で出た線が対角線 y=x と交わる点。隣の辺から出た線とここで接する
float2 _zellige_hankin_meeting_point(float contactAngle)
{
    float c = cos(contactAngle);
    float s = sin(contactAngle);
    float diagonal = 0.5 * c / (s + c);
    return float2(diagonal, diagonal);
}

// in: float2 タイル座標（セル 1 辺 = 1）, out float2 セル番号  out: float2 セル中心基準で 0<=y<=x<=0.5 の三角形に p4m 対称で畳んだ座標
// 反復なし
float2 fold_square_cell(float2 p, out float2 cellId)
{
    cellId = floor(p);
    float2 folded = abs(p - cellId - 0.5);
    if (folded.y > folded.x)
    {
        folded = folded.yx;
    }
    return folded;
}

// in: float2 fold_square_cell で畳んだ座標, float 辺と線のなす角（ラジアン。π/8〜3π/8 で星が開閉する）  out: float 辺中点から伸びる線（Hankin 法）までの距離
// 反復なし
float hankin_line_distance(float2 folded, float contactAngle)
{
    float2 meetingPoint = _zellige_hankin_meeting_point(_zellige_clamp_contact_angle(contactAngle));
    return _zellige_segment_distance(folded, ZELLIGE_EDGE_MIDPOINT, meetingPoint);
}

// in: float2 fold_square_cell で畳んだ座標, float 辺と線のなす角（ラジアン）  out: float Hankin 線を延長した直線への符号付き距離（セル角側が正、セル中心側が負）
// 反復なし
float hankin_corner_side(float2 folded, float contactAngle)
{
    float clampedAngle = _zellige_clamp_contact_angle(contactAngle);
    float2 towardCorner = float2(cos(clampedAngle), sin(clampedAngle));
    return dot(folded - ZELLIGE_EDGE_MIDPOINT, towardCorner);
}

// in: float2 星の中心基準の座標, float 重ねる正方形の半辺長  out: float 正方形 2 枚を 45 度ずらして重ねた 8 芒星の符号付き距離（内側が負）
// 反復なし
float khatam_star_distance(float2 p, float squareHalfSize)
{
    float2 diagonalRotated = float2(p.x - p.y, p.x + p.y) * ZELLIGE_INV_SQRT2;
    return min(_zellige_square_distance(p, squareHalfSize), _zellige_square_distance(diagonalRotated, squareHalfSize));
}

// in: float2 タイル座標（セル 1 辺 = 1）, float 辺と線のなす角（ラジアン。π/8〜3π/8 で星が開閉する）
// out: ZelligePattern .lineDistance=Hankin 線までの距離 .cornerSide=セル角側が正の符号付き距離 .starDistance=セル中心の 8 芒星の符号付き距離（先端が Hankin 線の交点に接する） .cellId=セル番号 .cornerId=最寄りのセル角の番号
// 距離はすべてセル 1 辺 = 1 の単位
// 反復なし
ZelligePattern zellige_pattern(float2 p, float contactAngle)
{
    ZelligePattern pattern;
    float2 folded = fold_square_cell(p, pattern.cellId);
    float2 meetingPoint = _zellige_hankin_meeting_point(_zellige_clamp_contact_angle(contactAngle));
    pattern.lineDistance = hankin_line_distance(folded, contactAngle);
    pattern.cornerSide = hankin_corner_side(folded, contactAngle);
    pattern.starDistance = khatam_star_distance(folded, meetingPoint.x);
    pattern.cornerId = floor(p + 0.5);
    return pattern;
}

static const float ZELLIGE_COLOR_REPEAT_CELLS = 8.0;
static const float2 ZELLIGE_HUE_WAVE_DIRECTION = float2(1.0, 3.0);

struct ZelligeTone
{
    float paletteOffset;
    float brightness;
    float lift;
};

struct ZelligeStyle
{
    float tileDensity;
    float lineWidth;
    float segmentCount;
    float rotationSpeed;
    float scrollSpeed;
    float contactAngleDegrees;
    float contactAngleAmplitudeDegrees;
    float contactAngleSpeed;
    float3 palettePhase;
    float hueVariation;
    ZelligeTone centerGroundTone;
    ZelligeTone cornerGroundTone;
    ZelligeTone starTone;
    ZelligeTone lineTone;
};

ZelligeTone _zellige_tone(float paletteOffset, float brightness, float lift)
{
    ZelligeTone tone;
    tone.paletteOffset = paletteOffset;
    tone.brightness = brightness;
    tone.lift = lift;
    return tone;
}

float3 _zellige_tone_color(ZelligeTone tone, float hueShift, float3 palettePhase)
{
    return cosine_palette(tone.paletteOffset + hueShift, palettePhase) * tone.brightness + tone.lift;
}

// 色の周期とスクロールの周期を揃え、スクロールが 1 周しても色が飛ばないようにしている
float2 _zellige_tile_coord(float2 p, ZelligeStyle style)
{
    float rotation = cycle_by_time(style.rotationSpeed, 2.0 * FRACTAL_PI);
    float2 folded = fold_kaleidoscope(p, style.segmentCount, rotation);
    float scroll = cycle_by_time(style.scrollSpeed, ZELLIGE_COLOR_REPEAT_CELLS);
    return folded * style.tileDensity + float2(scroll, 0.0);
}

float _zellige_hue_shift(float2 regionId, float hueVariation)
{
    return hueVariation * sin(2.0 * FRACTAL_PI * dot(regionId, ZELLIGE_HUE_WAVE_DIRECTION) / ZELLIGE_COLOR_REPEAT_CELLS);
}

// out: ZelligeStyle zellige_color の推奨値
// 反復なし
ZelligeStyle zellige_default_style()
{
    ZelligeStyle style;
    style.tileDensity = 4.0;
    style.lineWidth = 0.05;
    style.segmentCount = 8.0;
    style.rotationSpeed = 0.1;
    style.scrollSpeed = 0.2;
    style.contactAngleDegrees = 45.0;
    style.contactAngleAmplitudeDegrees = 15.0;
    style.contactAngleSpeed = 0.5;
    style.palettePhase = float3(0.0, 0.1, 0.2);
    style.hueVariation = 0.05;
    style.centerGroundTone = _zellige_tone(0.08, 0.8, 0.0);
    style.cornerGroundTone = _zellige_tone(0.5, 0.9, 0.03);
    style.starTone = _zellige_tone(0.6, 1.0, 0.0);
    style.lineTone = _zellige_tone(0.0, 0.25, 0.7);
    return style;
}

ZelligePattern _zellige_animated_pattern(float2 tileCoord, ZelligeStyle style)
{
    float contactAngle = radians(oscillate_by_time(style.contactAngleDegrees, style.contactAngleAmplitudeDegrees, style.contactAngleSpeed));
    return zellige_pattern(tileCoord, contactAngle);
}

float _zellige_drawn_star_distance(ZelligePattern pattern, ZelligeStyle style)
{
    return pattern.starDistance + style.lineWidth;
}

float _zellige_outline_distance(ZelligePattern pattern, ZelligeStyle style)
{
    float distanceInCells = min(pattern.lineDistance, abs(_zellige_drawn_star_distance(pattern, style)));
    return distanceInCells / style.tileDensity;
}

float3 _zellige_shade(float2 tileCoord, ZelligePattern pattern, ZelligeStyle style)
{
    float smoothing = edge_smoothing_width(tileCoord);
    float halfLineWidth = 0.5 * style.lineWidth;
    float lineMask = smoothstep(halfLineWidth + smoothing, halfLineWidth - smoothing, pattern.lineDistance);
    float starMask = smoothstep(smoothing, -smoothing, _zellige_drawn_star_distance(pattern, style));
    float cornerMask = smoothstep(-smoothing, smoothing, pattern.cornerSide);

    float cellHue = _zellige_hue_shift(pattern.cellId, style.hueVariation);
    float cornerHue = _zellige_hue_shift(pattern.cornerId, style.hueVariation);
    float3 centerGroundColor = _zellige_tone_color(style.centerGroundTone, cellHue, style.palettePhase);
    float3 cornerGroundColor = _zellige_tone_color(style.cornerGroundTone, cornerHue, style.palettePhase);
    float3 starColor = _zellige_tone_color(style.starTone, cellHue, style.palettePhase);
    float3 lineColor = _zellige_tone_color(style.lineTone, 0.0, style.palettePhase);

    float3 groundColor = lerp(centerGroundColor, cornerGroundColor, cornerMask);
    float3 tiled = lerp(groundColor, starColor, starMask);
    return lerp(tiled, lineColor, lineMask);
}

// in: float2 座標（[-1,1]）, ZelligeStyle 見た目（lineWidth はセル 1 辺 = 1 の単位）  out: float3 万華鏡で折りたたんだゼリージュ（8 芒星と Hankin 線）の色。回転・スクロール・星の開閉が時間で動く
// 反復なし。fwidth を使うのでフラグメントシェーダー専用
float3 zellige_color(float2 p, ZelligeStyle style)
{
    float2 tileCoord = _zellige_tile_coord(p, style);
    return _zellige_shade(tileCoord, _zellige_animated_pattern(tileCoord, style), style);
}

// in: float2 座標（[-1,1]）, ZelligeStyle 見た目, out float2 zellige_distance の座標空間での勾配（正規化しない）  out: float3 zellige_color と同じ色
// 反復なし。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 zellige_color(float2 p, ZelligeStyle style, out float2 gradient)
{
    float2 tileCoord = _zellige_tile_coord(p, style);
    ZelligePattern pattern = _zellige_animated_pattern(tileCoord, style);
    gradient = screen_space_gradient(_zellige_outline_distance(pattern, style), p);
    return _zellige_shade(tileCoord, pattern, style);
}

// in: float2 座標（[-1,1]）  out: float3 推奨値で描いた zellige_color
// 反復なし
float3 zellige_color(float2 p)
{
    return zellige_color(p, zellige_default_style());
}

// in: float2 座標（[-1,1]）, out float2 zellige_distance の座標空間での勾配（正規化しない）  out: float3 推奨値で描いた zellige_color
// 反復なし。fwidth と ddx/ddy を使うのでフラグメントシェーダー専用
float3 zellige_color(float2 p, out float2 gradient)
{
    return zellige_color(p, zellige_default_style(), gradient);
}

// in: float2 座標（[-1,1]）, ZelligeStyle 見た目  out: float zellige_color が描く Hankin 線の中心線と星の輪郭のうち近い方までの符号なし距離（p と同じ単位）
// 反復なし
float zellige_distance(float2 p, ZelligeStyle style)
{
    float2 tileCoord = _zellige_tile_coord(p, style);
    return _zellige_outline_distance(_zellige_animated_pattern(tileCoord, style), style);
}

// in: float2 座標（[-1,1]）  out: float 推奨値での zellige_distance
// 反復なし
float zellige_distance(float2 p)
{
    return zellige_distance(p, zellige_default_style());
}

#endif
