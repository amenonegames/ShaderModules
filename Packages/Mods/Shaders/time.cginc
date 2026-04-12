
float get_framed_time( float frameInterval )
{
    float frame = floor(_Time.y / frameInterval);
    return frame;
}