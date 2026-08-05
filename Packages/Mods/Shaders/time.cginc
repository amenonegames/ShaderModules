#ifndef AMENONE_TIME_INCLUEDED
#define AMENONE_TIME_INCLUEDED
float get_framed_time( float frameInterval )
{
    float frame = floor(_Time.y / frameInterval);
    return frame;
}
#endif