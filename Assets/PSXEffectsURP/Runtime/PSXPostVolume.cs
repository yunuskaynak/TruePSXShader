using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace PSX
{
    /// <summary>
    /// PS1 post-process ayarlari. URP Volume sistemi ile calisir:
    /// bir Volume'e "PSX > PSX Post Process" override'i ekleyin.
    /// Hicbir Volume yoksa asagidaki varsayilan degerler (klasik PS1
    /// gorunumu) otomatik uygulanir.
    /// </summary>
    [Serializable]
    [VolumeComponentMenu("PSX/PSX Post Process")]
    public sealed class PSXPostVolume : VolumeComponent
    {
        [Header("Renk")]
        [Tooltip("Kanal basina renk biti. PS1 = 5 (15-bit renk).")]
        public ClampedIntParameter colorDepth = new ClampedIntParameter(5, 1, 8);

        [Tooltip("PS1 4x4 dither matrisi siddeti. 1 = donanim dogrulugu, 0 = kapali.")]
        public ClampedFloatParameter ditherIntensity = new ClampedFloatParameter(1f, 0f, 4f);

        [Tooltip("Gokyuzu da dither'lansin mi? Kapaliysa derinlik dokusu kullanilarak gokyuzu haric tutulur.")]
        public BoolParameter ditherSky = new BoolParameter(true);

        [Header("Ton (orijinal PSXEffects)")]
        [Tooltip("Karanlik tonlari koyulastirip hafif kirmiziya ceker (orijinal 'Darken Darks / Favor Red').")]
        public ClampedFloatParameter favorRed = new ClampedFloatParameter(1f, 0f, 1f);

        [Tooltip("PS1 oyunlarindaki gibi ekrani karartan fade (orijinal 'Subtraction Fade').")]
        public ClampedFloatParameter subtractFade = new ClampedFloatParameter(0f, 0f, 1f);

        [Header("CRT / Ekran")]
        [Tooltip("Scanline siddeti. 0 = kapali.")]
        public ClampedFloatParameter scanlineIntensity = new ClampedFloatParameter(0f, 0f, 1f);

        [Tooltip("Scanline yonu dikey olsun mu?")]
        public BoolParameter verticalScanlines = new BoolParameter(false);

        [Tooltip("Interlace (alternatif satir titremesi) siddeti. 0 = kapali.")]
        public ClampedFloatParameter interlacing = new ClampedFloatParameter(0f, 0f, 1f);

        [Tooltip("CRT tup bombeleme miktari. 0 = kapali.")]
        public ClampedFloatParameter crtCurvature = new ClampedFloatParameter(0f, 0f, 1f);

        [Tooltip("Kose kararmasi (vignette). 0 = kapali.")]
        public ClampedFloatParameter vignette = new ClampedFloatParameter(0f, 0f, 1f);
    }
}
