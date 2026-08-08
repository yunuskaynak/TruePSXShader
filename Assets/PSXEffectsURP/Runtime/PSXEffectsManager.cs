using UnityEngine;

namespace PSX
{
    /// <summary>
    /// PSX Effects icin merkezi yonetici. Sahneye bir tane eklenmesi yeterlidir
    /// (Prefabs/PSX Effects prefabini surukleyin). Geometri efektlerini
    /// (vertex snapping, affine mapping, cizim mesafesi, PS1 sisi) global shader
    /// degiskenleri uzerinden yonetir; post-process ayarlari URP Volume
    /// sistemindeki "PSX Post Process" override'i ile yapilir.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    [AddComponentMenu("PSX Effects/PSX Effects Manager")]
    public class PSXEffectsManager : MonoBehaviour
    {
        public enum ResolutionMode
        {
            FactorOfScreen, // Ekran cozunurlugu / faktor
            Fixed           // Sabit cozunurluk (orn. 320x240)
        }

        public enum FogMode
        {
            URP,        // Unity'nin kendi sisi (z'de lineer/exponential)
            PS1DepthCue // GTE IR0 egrisi: 1/z'de lineer, tek "far color"a lerp
        }

        public static PSXEffectsManager Active { get; private set; }

        [Header("Cozunurluk")]
        [Tooltip("Sabit: klasik 320x240 gibi. FactorOfScreen: ekran cozunurlugunu bolerek kullanir.")]
        public ResolutionMode resolutionMode = ResolutionMode.Fixed;
        [Tooltip("Sabit modda hedef cozunurluk. Donanimda gecerli genislikler: 256/320/368/512/640.")]
        public Vector2Int fixedResolution = new Vector2Int(320, 240);
        [Tooltip("Sabit modda yuksekligi koruyup genisligi ekran oranina gore hesaplar (16:9'da 426x240).")]
        public bool matchScreenAspect = true;
        [Range(1, 16)]
        [Tooltip("FactorOfScreen modunda bolme faktoru.")]
        public int resolutionFactor = 4;

        [Header("Kare Hizi")]
        [Tooltip("-1 = sinirsiz. Orijinaldeki 'Target Framerate'.")]
        public int targetFrameRate = -1;
        [Range(0, 8)]
        [Tooltip("Goruntuyu N kare boyunca tutar (orijinaldeki 'Frame Skip'). 0 = kapali.")]
        public int frameHold = 0;

        [Header("Geometri")]
        [Tooltip("Vertex snapping (poligon titremesi).")]
        public bool vertexSnapping = true;
        [Range(0f, 1f)]
        [Tooltip("Snap siddeti. 1 = tam PS1.")]
        public float snapAmount = 1f;
        [Tooltip("Ekran yerine dunya uzayinda snap uygula. NOT: bu donanim davranisi degildir, sanatsal bir secenektir.")]
        public bool worldSpaceSnapping = false;
        [Tooltip("Dunya uzayi snap birimi (metre).")]
        public float worldSnapUnits = 0.05f;

        [Range(0f, 1f)]
        [Tooltip("Affine texture mapping siddeti. 1 = tam PS1 dokusu kaymasi.")]
        public float affineAmount = 1f;

        [Tooltip("0 = kapali. Poligonlarin kameradan bu mesafeden sonra cizilmemesi (PS1 draw distance).")]
        public float drawDistance = 0f;

        [Tooltip("0 = kapali. PS1'de iki vertex arasi mesafe 1023x511 pikseli asarsa poligon HIC cizilmez; " +
                 "pratikte kameraya cok yakin buyuk yuzeyler yok olur. Bu deger o mesafeyi taklit eder.")]
        public float nearCullDistance = 0f;

        [Header("Sis (PS1 Depth Cue)")]
        [Tooltip("PS1 modunda sis GTE'nin IR0 egrisini kullanir: z'de degil 1/z'de lineer, ve tek bir 'far color'a lerp edilir.")]
        public FogMode fogMode = FogMode.URP;
        [Tooltip("Sisin baslangic mesafesi (IR0 = 0).")]
        public float fogStart = 10f;
        [Tooltip("Sisin tam doygunluga ulastigi mesafe (IR0 = 1).")]
        public float fogEnd = 60f;
        [Tooltip("PS1 'far color' (FC). PS1 oyunlarinda genellikle siyah veya koyu maviydi.")]
        [ColorUsage(false, false)]
        public Color fogColor = Color.black;

        [Header("Golgeler")]
        [Tooltip("PSX modu: golgeler cikarimsal (subtractive) uygulanir - PS1 yari-saydamlik modu 2 (B - F).")]
        public bool psxStyleShadows = false;
        [Range(0f, 1f)]
        public float psxShadowIntensity = 0.5f;

        [Header("Kamera")]
        [Tooltip("Kamera pozisyonunu birimlere yuvarlayarak PS1 kamera titremesi olusturur.")]
        public bool cameraSnapping = false;
        public float cameraSnapUnits = 0.05f;
        [Tooltip("Bos birakilirsa Camera.main kullanilir.")]
        public Camera snapCamera;

        [Header("Genel")]
        [Tooltip("Post-process zincirini calistir (dusuk cozunurluk + dither + posterizasyon).")]
        public bool enablePostProcessing = true;
        [Tooltip("Efekti Scene gorunumune de uygula.")]
        public bool applyInSceneView = true;

        // Global shader property ID'leri
        static readonly int TargetResId = Shader.PropertyToID("_PSX_TargetRes");
        static readonly int SnapAmountId = Shader.PropertyToID("_PSX_SnapAmount");
        static readonly int WorldSnapId = Shader.PropertyToID("_PSX_WorldSnap");
        static readonly int WorldSnapUnitsId = Shader.PropertyToID("_PSX_WorldSnapUnits");
        static readonly int AffineAmountId = Shader.PropertyToID("_PSX_AffineAmount");
        static readonly int DrawDistanceId = Shader.PropertyToID("_PSX_DrawDistance");
        static readonly int NearCullId = Shader.PropertyToID("_PSX_NearCullDist");
        static readonly int ShadowModeId = Shader.PropertyToID("_PSX_ShadowMode");
        static readonly int ShadowIntensityId = Shader.PropertyToID("_PSX_ShadowIntensity");
        static readonly int FogModeId = Shader.PropertyToID("_PSX_FogMode");
        static readonly int FogParamsId = Shader.PropertyToID("_PSX_FogParams");
        static readonly int FogColorId = Shader.PropertyToID("_PSX_FogColor");

        Vector3 m_LastSnappedCamPos;
        Vector3 m_RealCamPos;
        bool m_HasRealCamPos;

        void OnEnable()
        {
            if (Active != null && Active != this)
                Debug.LogWarning("[PSXEffects] Sahnede birden fazla PSXEffectsManager var. Sonuncusu aktif olacak.", this);
            Active = this;

            // Render feature henuz calismamis olabilir (ya da renderer'a hic
            // eklenmemis olabilir). _PSX_TargetRes yazilmazsa shader tarafinda
            // grid 1.0'a duser ve tum geometri 3x3 NDC kafesine cokerdi.
            EnsureTargetResolution();
            PushGlobals();
        }

        void OnDisable()
        {
            if (Active == this)
                Active = null;
            ResetGlobals();
        }

        void Update()
        {
            PushGlobals();

            if (Application.isPlaying)
                Application.targetFrameRate = targetFrameRate;
        }

        void LateUpdate()
        {
            HandleCameraSnapping();
        }

        /// <summary>Global shader degiskenlerini gunceller. Degerleri koddan
        /// degistirirseniz cagirmaniza gerek yoktur; her karede islenir.</summary>
        public void PushGlobals()
        {
            // Guvenlik agi: render feature yoksa/devre disiysa cozunurluk
            // hicbir zaman yazilmaz. Her karede kontrol etmek ucuzdur.
            EnsureTargetResolution();

            Shader.SetGlobalFloat(SnapAmountId, vertexSnapping ? snapAmount : 0f);
            Shader.SetGlobalFloat(WorldSnapId, worldSpaceSnapping ? 1f : 0f);
            Shader.SetGlobalFloat(WorldSnapUnitsId, Mathf.Max(0.0001f, worldSnapUnits));
            Shader.SetGlobalFloat(AffineAmountId, affineAmount);
            Shader.SetGlobalFloat(DrawDistanceId, Mathf.Max(0f, drawDistance));
            Shader.SetGlobalFloat(NearCullId, Mathf.Max(0f, nearCullDistance));
            Shader.SetGlobalFloat(ShadowModeId, psxStyleShadows ? 1f : 0f);
            Shader.SetGlobalFloat(ShadowIntensityId, psxShadowIntensity);

            PushFog();
        }

        /// <summary>
        /// PS1 depth-cue sis katsayilari.
        /// Donanimda IR0 = (H*0x20000/SZ3) * DQA + DQB, yani sis 1/z'de lineerdir.
        /// IR0(fogStart) = 0 ve IR0(fogEnd) = 1 kosullarindan:
        ///   DQA = (start * end) / (start - end)
        ///   DQB = end / (end - start)
        /// </summary>
        void PushFog()
        {
            Shader.SetGlobalFloat(FogModeId, fogMode == FogMode.PS1DepthCue ? 1f : 0f);

            float start = Mathf.Max(0.01f, fogStart);
            float end = Mathf.Max(start + 0.01f, fogEnd);
            float dqa = (start * end) / (start - end);
            float dqb = end / (end - start);

            Shader.SetGlobalVector(FogParamsId, new Vector4(dqa, dqb, start, end));
            Shader.SetGlobalColor(FogColorId, fogColor);
        }

        static void ResetGlobals()
        {
            Shader.SetGlobalFloat(SnapAmountId, 0f);
            Shader.SetGlobalFloat(WorldSnapId, 0f);
            Shader.SetGlobalFloat(AffineAmountId, 0f);
            Shader.SetGlobalFloat(DrawDistanceId, 0f);
            Shader.SetGlobalFloat(NearCullId, 0f);
            Shader.SetGlobalFloat(ShadowModeId, 0f);
            Shader.SetGlobalFloat(FogModeId, 0f);
        }

        /// <summary>
        /// _PSX_TargetRes hic yazilmamissa (veya bozuksa) ekran boyutuna gore
        /// mantikli bir varsayilan yazar. Render feature aktifse zaten her kare
        /// dogru degeri gonderir, bu yalnizca guvenlik agidir.
        /// </summary>
        void EnsureTargetResolution()
        {
            Vector4 current = Shader.GetGlobalVector(TargetResId);
            if (current.x >= 2f && current.y >= 2f)
                return;

            int w = Mathf.Max(2, Screen.width);
            int h = Mathf.Max(2, Screen.height);
            PushTargetResolution(GetTargetResolution(w, h));
        }

        /// <summary>Verilen kamera boyutlari icin hedef dusuk cozunurlugu dondurur.</summary>
        public Vector2Int GetTargetResolution(int screenWidth, int screenHeight)
        {
            Vector2Int res;
            if (resolutionMode == ResolutionMode.Fixed)
            {
                res = fixedResolution;
                if (matchScreenAspect && screenHeight > 0)
                {
                    float aspect = (float)screenWidth / screenHeight;
                    res = new Vector2Int(Mathf.RoundToInt(fixedResolution.y * aspect), fixedResolution.y);
                }
            }
            else
            {
                int f = Mathf.Max(1, resolutionFactor);
                res = new Vector2Int(screenWidth / f, screenHeight / f);
            }
            res.x = Mathf.Clamp(res.x, 2, 4096);
            res.y = Mathf.Clamp(res.y, 2, 4096);
            return res;
        }

        /// <summary>Frame hold (kare atlama) icin bu karede yeni goruntu alinmali mi?</summary>
        public bool ShouldRefreshFrame()
        {
            if (!Application.isPlaying || frameHold <= 0)
                return true;
            return Time.frameCount % (frameHold + 1) == 0;
        }

        /// <summary>Render feature'in kullandigi hedef cozunurlugu global olarak yazar.</summary>
        public void PushTargetResolution(Vector2Int res)
        {
            Shader.SetGlobalVector(TargetResId, new Vector4(res.x, res.y, 1f / res.x, 1f / res.y));
        }

        void HandleCameraSnapping()
        {
            if (!cameraSnapping || !Application.isPlaying)
            {
                m_HasRealCamPos = false;
                return;
            }

            Camera cam = snapCamera != null ? snapCamera : Camera.main;
            if (cam == null)
                return;

            Transform t = cam.transform;
            float units = Mathf.Max(0.0001f, cameraSnapUnits);

            if (!m_HasRealCamPos)
            {
                m_RealCamPos = t.position;
                m_LastSnappedCamPos = t.position;
                m_HasRealCamPos = true;
            }
            else
            {
                // Oyun kodunun uyguladigi hareket deltasini gercek pozisyona ekle
                m_RealCamPos += t.position - m_LastSnappedCamPos;
            }

            Vector3 snapped = new Vector3(
                Mathf.Round(m_RealCamPos.x / units) * units,
                Mathf.Round(m_RealCamPos.y / units) * units,
                Mathf.Round(m_RealCamPos.z / units) * units);

            t.position = snapped;
            m_LastSnappedCamPos = snapped;
        }

        void OnDrawGizmosSelected()
        {
            if (cameraSnapping && m_HasRealCamPos)
            {
                Gizmos.color = new Color(1f, 0f, 0f, 0.5f);
                Gizmos.DrawSphere(m_RealCamPos, 0.25f);
            }
        }
    }
}
