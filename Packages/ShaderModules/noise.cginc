
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
half noise_test(in half2 st)
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

half stepnoise(in half2 st)
{
    // Splited integer and float values.
    half2 i = floor(st);
    half2 f = frac(st);

    half a = random(i + half2(0.0, 0.0));
    half b = random(i + half2(1.0, 0.0));
    half c = random(i + half2(0.0, 1.0));
    half d = random(i + half2(1.0, 1.0));

    // -2.0f^3 + 3.0f^2
    half2 u = f * f * (3.0 - 2.0 * f);

    return round(lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y);
}

// fractional brown motion
//
// Reduce amplitude multiplied by 0.5, and frequency multiplied by 2.
half fbm(in half2 st,int NUM_OCTAVES)
{
    half v = 0.0;
    half a = 0.5;

    for (int i = 0; i < NUM_OCTAVES; i++)
    {
        v += a * noise(st);
        st = st * 2.0;
        a *= 0.5;
    }

    return v;
}

float fbmTex(sampler2D tex , float2 uv){
    return tex2D(tex, uv).r; // 事前に作成したノイズテクスチャを使用
    // return tex2D(tex, frac(uv)).r; // 事前に作成したノイズテクスチャを使用
}
// #define FBM_T_FUNCEX(value, func) func(value)
// テクスチャを使用したDomain Warp
// テクスチャのR値を参照する
float2 textureDomainWarp(float2 st , sampler2D noiseTexture ,float distortion,float time){
    // 波の細かさ
    // half2 w = _Distortion;
    half2 w =distortion;

    // 波の速さ 
    float2 v1 = float2(0.35 , 0.12) * time;
    float f = fbmTex(noiseTexture, st);
    f = fbmTex(noiseTexture, st + f*w + v1 );
    return st + f*w - w*0.5;
}