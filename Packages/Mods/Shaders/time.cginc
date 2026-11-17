#ifndef AMENONE_TIME_INCLUEDED
#define AMENONE_TIME_INCLUEDED
float get_framed_time( float frameInterval )
{
    float frame = floor(_Time.y / frameInterval);
    return frame;
}

// in: float 中心値, float 振幅, float 角速度（rad/s）  out: float 時間とともに中心値のまわりを正弦波で揺れる値
float oscillate_by_time(float center, float amplitude, float speed)
{
    return center + amplitude * sin(_Time.y * speed);
}

// in: float 1 秒あたりの増加量, float 周期  out: float 時間とともに増え、周期で 0 に戻る値
float cycle_by_time(float rate, float period)
{
    return fmod(_Time.y * rate, period);
}
#endif