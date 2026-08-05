using UnityEngine;

namespace PSX
{
    /// <summary>
    /// PSX Effects icin merkezi yonetici. Sahneye bir tane eklenmesi yeterlidir
    /// (Prefabs/PSX Effects prefabini surukleyin). Geometri efektlerini
    /// (vertex snapping, affine mapping, cizim mesafesi) global shader
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

        public static PSXEffectsManager Active { get; private set; }

        [Header("Cozunurluk")]
        [Tooltip("Sabit: klasik 320x240 gibi. FactorOfScreen: ekran cozunurlugunu bolerek kullanir.")]
        public ResolutionMode resolutionMode = ResolutionMode.Fixed;
        [Tooltip("Sabit modda hedef cozunurluk.")]
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
        [Tooltip("Ekran yerine dunya uzayinda snap uygula.")]
        public bool worldSpaceSnapping = false;
        [Tooltip("Dunya uzayi snap birimi (metre).")]
        public float worldSnapUnits = 0.05f;

        [Range(0f, 1f)]
        [Tooltip("Affine texture mapping siddeti. 1 = tam PS1 dokusu kaymasi.")]
        public float affineAmount = 1f;

        [Tooltip("0 = kapali. Poligonlarin kameradan bu mesafeden sonra cizilmemesi (PS1 draw distance).")]
        public float drawDistance = 0f;

        [Header("Golgeler")]
        [Tooltip("PSX modu: golgeler cikarimsal (subtractive) uygulanir.")]
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
        static readonly int ShadowModeId = Shader.PropertyToID("_PSX_ShadowMode");
        static readonly int ShadowIntensityId = Shader.PropertyToID("_PSX_ShadowIntensity");

        Vector3 m_LastSnappedCamPos;
        Vector3 m_RealCamPos;
        bool m_HasRealCamPos;

        void OnEnable()
        {
            if (Active != null && Active != this)
                Debug.LogWarning("[PSXEffects] Sahnede birden fazla PSXEffectsManager var. Sonuncusu aktif olacak.", this);
            Active = this;
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
            Shader.SetGlobalFloat(SnapAmountId, vertexSnapping ? snapAmount : 0f);
            Shader.SetGlobalFloat(WorldSnapId, worldSpaceSnapping ? 1f : 0f);
            Shader.SetGlobalFloat(WorldSnapUnitsId, Mathf.Max(0.0001f, worldSnapUnits));
            Shader.SetGlobalFloat(AffineAmountId, affineAmount);
            Shader.SetGlobalFloat(DrawDistanceId, Mathf.Max(0f, drawDistance));
            Shader.SetGlobalFloat(ShadowModeId, psxStyleShadows ? 1f : 0f);
            Shader.SetGlobalFloat(ShadowIntensityId, psxShadowIntensity);
        }

        static void ResetGlobals()
        {
            Shader.SetGlobalFloat(SnapAmountId, 0f);
            Shader.SetGlobalFloat(WorldSnapId, 0f);
            Shader.SetGlobalFloat(AffineAmountId, 0f);
            Shader.SetGlobalFloat(DrawDistanceId, 0f);
            Shader.SetGlobalFloat(ShadowModeId, 0f);
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
