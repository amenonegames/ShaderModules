
static const float EASE_PI = 3.14159265358979;

// in: float 進行度t[0,1]  out: float 線形（変換なし）
float ease_linear(float t)
{
    return t;
}

// in: float 進行度t[0,1]  out: float 最初が緩やかなsineイージング
float ease_in_sine(float t)
{
    return 1.0 - cos((t * EASE_PI) * 0.5);
}

// in: float 進行度t[0,1]  out: float 最後が緩やかなsineイージング
float ease_out_sine(float t)
{
    return sin((t * EASE_PI) * 0.5);
}

// in: float 進行度t[0,1]  out: float 両端が緩やかなsineイージング
float ease_in_out_sine(float t)
{
    return -(cos(EASE_PI * t) - 1.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 二次関数の加速イージング
float ease_in_quad(float t)
{
    return t * t;
}

// in: float 進行度t[0,1]  out: float 二次関数の減速イージング
float ease_out_quad(float t)
{
    return 1.0 - (1.0 - t) * (1.0 - t);
}

// in: float 進行度t[0,1]  out: float 二次関数の加減速イージング
float ease_in_out_quad(float t)
{
    return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 三次関数の加速イージング
float ease_in_cubic(float t)
{
    return t * t * t;
}

// in: float 進行度t[0,1]  out: float 三次関数の減速イージング
float ease_out_cubic(float t)
{
    return 1.0 - pow(1.0 - t, 3.0);
}

// in: float 進行度t[0,1]  out: float 三次関数の加減速イージング
float ease_in_out_cubic(float t)
{
    return t < 0.5 ? 4.0 * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 3.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 四次関数の加速イージング
float ease_in_quart(float t)
{
    return t * t * t * t;
}

// in: float 進行度t[0,1]  out: float 四次関数の減速イージング
float ease_out_quart(float t)
{
    return 1.0 - pow(1.0 - t, 4.0);
}

// in: float 進行度t[0,1]  out: float 四次関数の加減速イージング
float ease_in_out_quart(float t)
{
    return t < 0.5 ? 8.0 * t * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 4.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 五次関数の加速イージング
float ease_in_quint(float t)
{
    return t * t * t * t * t;
}

// in: float 進行度t[0,1]  out: float 五次関数の減速イージング
float ease_out_quint(float t)
{
    return 1.0 - pow(1.0 - t, 5.0);
}

// in: float 進行度t[0,1]  out: float 五次関数の加減速イージング
float ease_in_out_quint(float t)
{
    return t < 0.5 ? 16.0 * t * t * t * t * t : 1.0 - pow(-2.0 * t + 2.0, 5.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 指数関数の加速イージング
float ease_in_expo(float t)
{
    return t <= 0.0 ? 0.0 : pow(2.0, 10.0 * t - 10.0);
}

// in: float 進行度t[0,1]  out: float 指数関数の減速イージング
float ease_out_expo(float t)
{
    return t >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t);
}

// in: float 進行度t[0,1]  out: float 指数関数の加減速イージング
float ease_in_out_expo(float t)
{
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return t < 0.5
        ? pow(2.0, 20.0 * t - 10.0) * 0.5
        : (2.0 - pow(2.0, -20.0 * t + 10.0)) * 0.5;
}

// in: float 進行度t[0,1]  out: float 円弧状の加速イージング
float ease_in_circ(float t)
{
    return 1.0 - sqrt(1.0 - t * t);
}

// in: float 進行度t[0,1]  out: float 円弧状の減速イージング
float ease_out_circ(float t)
{
    return sqrt(1.0 - (t - 1.0) * (t - 1.0));
}

// in: float 進行度t[0,1]  out: float 円弧状の加減速イージング
float ease_in_out_circ(float t)
{
    return t < 0.5
        ? (1.0 - sqrt(1.0 - pow(2.0 * t, 2.0))) * 0.5
        : (sqrt(1.0 - pow(-2.0 * t + 2.0, 2.0)) + 1.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float 一度引いてから進むbackイージング
float ease_in_back(float t)
{
    const float c1 = 1.70158;
    const float c3 = c1 + 1.0;
    return c3 * t * t * t - c1 * t * t;
}

// in: float 進行度t[0,1]  out: float 行き過ぎてから戻るbackイージング
float ease_out_back(float t)
{
    const float c1 = 1.70158;
    const float c3 = c1 + 1.0;
    return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0);
}

// in: float 進行度t[0,1]  out: float 両端で反動が付くbackイージング
float ease_in_out_back(float t)
{
    const float c1 = 1.70158;
    const float c2 = c1 * 1.525;
    return t < 0.5
        ? (pow(2.0 * t, 2.0) * ((c2 + 1.0) * 2.0 * t - c2)) * 0.5
        : (pow(2.0 * t - 2.0, 2.0) * ((c2 + 1.0) * (t * 2.0 - 2.0) + c2) + 2.0) * 0.5;
}

// in: float 進行度t[0,1]  out: float バネのように振動しながら始まるelasticイージング
float ease_in_elastic(float t)
{
    const float c4 = (2.0 * EASE_PI) / 3.0;
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return -pow(2.0, 10.0 * t - 10.0) * sin((10.0 * t - 10.75) * c4);
}

// in: float 進行度t[0,1]  out: float バネのように振動しながら収束するelasticイージング
float ease_out_elastic(float t)
{
    const float c4 = (2.0 * EASE_PI) / 3.0;
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return pow(2.0, -10.0 * t) * sin((10.0 * t - 0.75) * c4) + 1.0;
}

// in: float 進行度t[0,1]  out: float 両端で振動するelasticイージング
float ease_in_out_elastic(float t)
{
    const float c5 = (2.0 * EASE_PI) / 4.5;
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return t < 0.5
        ? -(pow(2.0, 20.0 * t - 10.0) * sin((20.0 * t - 11.125) * c5)) * 0.5
        : (pow(2.0, -20.0 * t + 10.0) * sin((20.0 * t - 11.125) * c5)) * 0.5 + 1.0;
}

// in: float 進行度t[0,1]  out: float 跳ねながら収束するbounceイージング
float ease_out_bounce(float t)
{
    const float n1 = 7.5625;
    const float d1 = 2.75;
    if (t < 1.0 / d1)
    {
        return n1 * t * t;
    }
    else if (t < 2.0 / d1)
    {
        t -= 1.5 / d1;
        return n1 * t * t + 0.75;
    }
    else if (t < 2.5 / d1)
    {
        t -= 2.25 / d1;
        return n1 * t * t + 0.9375;
    }
    else
    {
        t -= 2.625 / d1;
        return n1 * t * t + 0.984375;
    }
}

// in: float 進行度t[0,1]  out: float 跳ねながら始まるbounceイージング
float ease_in_bounce(float t)
{
    return 1.0 - ease_out_bounce(1.0 - t);
}

// in: float 進行度t[0,1]  out: float 両端で跳ねるbounceイージング
float ease_in_out_bounce(float t)
{
    return t < 0.5
        ? (1.0 - ease_out_bounce(1.0 - 2.0 * t)) * 0.5
        : (1.0 + ease_out_bounce(2.0 * t - 1.0)) * 0.5;
}

// in: float 進行度t[0,1], float 傾きの強さ(1=線形,大きいほど鋭い)  out: float 最初が緩やかな冪乗イージング
float ease_in(float t, float power)
{
    return pow(t, power);
}

// in: float 進行度t[0,1], float 傾きの強さ(1=線形,大きいほど鋭い)  out: float 最後が緩やかな冪乗イージング
float ease_out(float t, float power)
{
    return 1.0 - pow(1.0 - t, power);
}

// in: float 進行度t[0,1], float 傾きの強さ(1=線形,大きいほど鋭い)  out: float 両端が緩やかな冪乗イージング
float ease_in_out(float t, float power)
{
    return t < 0.5
        ? pow(2.0 * t, power) * 0.5
        : 1.0 - pow(2.0 - 2.0 * t, power) * 0.5;
}

// in: float 進行度t[0,1], float 傾きの強さ(1=線形,大きいほど鋭い)  out: float 前半out後半inで中央が緩やかな冪乗イージング
float ease_out_in(float t, float power)
{
    return t < 0.5
        ? (1.0 - pow(1.0 - 2.0 * t, power)) * 0.5
        : pow(2.0 * t - 1.0, power) * 0.5 + 0.5;
}
