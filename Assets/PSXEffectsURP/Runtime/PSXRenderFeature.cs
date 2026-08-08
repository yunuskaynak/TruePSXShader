using System;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

namespace PSX
{
    /// <summary>
    /// PS1 post-process zinciri: sahneyi dusuk cozunurluge indirir, nokta
    /// filtreleme ile geri buyutur ve bu sirada posterizasyon, dither,
    /// scanline, interlace ve CRT efektlerini uygular.
    /// Unity 6 Render Graph API'si ile calisir.
    /// </summary>
    public class PSXRenderFeature : ScriptableRendererFeature
    {
        class PSXPostPass : ScriptableRenderPass
        {
            internal Material material;

            RTHandle m_History;     // frame hold icin kalici dusuk cozunurluk RT

            static readonly int DepthTexId = Shader.PropertyToID("_PSX_DepthTex");
            static readonly int TargetResId = Shader.PropertyToID("_PSX_TargetRes");
            static readonly int Params0Id = Shader.PropertyToID("_PSX_PostParams0");
            static readonly int Params1Id = Shader.PropertyToID("_PSX_PostParams1");
            static readonly int Params2Id = Shader.PropertyToID("_PSX_PostParams2");

            class PassData
            {
                public Material material;
                public TextureHandle source;
                public TextureHandle depth;
                public bool useDepth;
            }

            internal void ReleaseTargets()
            {
                m_History?.Release();
                m_History = null;
            }

            void ApplySettings(Material mat, Vector2Int res, bool hasDepth)
            {
                var v = VolumeManager.instance.stack.GetComponent<PSXPostVolume>();

                float colorBits = v != null ? v.colorDepth.value : 5f;
                float ditherI = v != null ? v.ditherIntensity.value : 1f;
                float dSky = v != null ? (v.ditherSky.value ? 1f : 0f) : 1f;
                float fade = v != null ? v.subtractFade.value : 0f;
                float slI = v != null ? v.scanlineIntensity.value : 0f;
                float slV = v != null ? (v.verticalScanlines.value ? 1f : 0f) : 0f;
                float il = v != null ? v.interlacing.value : 0f;
                float crt = v != null ? v.crtCurvature.value : 0f;
                float vig = v != null ? v.vignette.value : 0f;
                float red = v != null ? v.favorRed.value : 1f;

                float parity = Time.frameCount & 1;

                mat.SetVector(TargetResId, new Vector4(res.x, res.y, 1f / res.x, 1f / res.y));
                mat.SetVector(Params0Id, new Vector4(colorBits, ditherI, dSky, fade));
                mat.SetVector(Params1Id, new Vector4(slI, slV, il, parity));
                mat.SetVector(Params2Id, new Vector4(crt, vig, red, hasDepth ? 1f : 0f));
            }

            /// <summary>
            /// PSX/Lit her piksele "dither uygunlugu" bayragini alpha kanalinda
            /// yazar (donanim kurali: yalnizca gouraud/modulasyonlu poligonlar
            /// dither alir). Dusuk cozunurluk hedefinde alpha yoksa bu maske
            /// kaybolur, bu yuzden alpha-kapasiteli bir formata gecilir.
            /// Kamera renk hedefinde alpha yoksa maske 1 okunur ve eski
            /// davranis (her seyi dither'la) korunur.
            /// </summary>
            static void EnsureAlphaChannel(ref RenderTextureDescriptor desc, bool hdr)
            {
                if (desc.graphicsFormat != GraphicsFormat.None &&
                    GraphicsFormatUtility.HasAlphaChannel(desc.graphicsFormat))
                    return;

                GraphicsFormat target = hdr
                    ? GraphicsFormat.R16G16B16A16_SFloat
                    : GraphicsFormat.R8G8B8A8_UNorm;

                if (SystemInfo.IsFormatSupported(target, GraphicsFormatUsage.Render))
                    desc.graphicsFormat = target;
            }

            // ----------------------------------------------------------
            //  Render Graph yolu (Unity 6 varsayilani)
            // ----------------------------------------------------------
            public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
            {
                var mgr = PSXEffectsManager.Active;
                if (mgr == null || material == null)
                    return;

                var resourceData = frameData.Get<UniversalResourceData>();
                var cameraData = frameData.Get<UniversalCameraData>();

                if (resourceData.isActiveTargetBackBuffer)
                    return;

                var desc = cameraData.cameraTargetDescriptor;
                Vector2Int res = mgr.GetTargetResolution(desc.width, desc.height);

                var lowDesc = desc;
                lowDesc.width = res.x;
                lowDesc.height = res.y;
                lowDesc.depthBufferBits = 0;
                lowDesc.msaaSamples = 1;
                lowDesc.useMipMap = false;
                EnsureAlphaChannel(ref lowDesc, cameraData.isHdrEnabled);

                bool useHistory = cameraData.cameraType == CameraType.Game && mgr.frameHold > 0;
                bool refresh = true;
                TextureHandle lowRes;

                if (useHistory)
                {
                    refresh = mgr.ShouldRefreshFrame();
                    if (RenderingUtils.ReAllocateHandleIfNeeded(ref m_History, lowDesc,
                            FilterMode.Point, TextureWrapMode.Clamp, name: "_PSX_LowResHistory"))
                        refresh = true;
                    lowRes = renderGraph.ImportTexture(m_History);
                }
                else
                {
                    lowRes = UniversalRenderer.CreateRenderGraphTexture(renderGraph, lowDesc,
                        "_PSX_LowRes", false, FilterMode.Point);
                }

                if (refresh)
                {
                    renderGraph.AddBlitPass(resourceData.activeColorTexture, lowRes,
                        Vector2.one, Vector2.zero, passName: "PSX Downscale");
                }

                var finalDesc = desc;
                finalDesc.depthBufferBits = 0;
                finalDesc.msaaSamples = 1;
                TextureHandle destination = UniversalRenderer.CreateRenderGraphTexture(renderGraph,
                    finalDesc, "_PSX_Output", false);

                bool hasDepth = resourceData.cameraDepthTexture.IsValid();
                ApplySettings(material, res, hasDepth);

                using (var builder = renderGraph.AddRasterRenderPass<PassData>("PSX Post Process", out var passData))
                {
                    passData.material = material;
                    passData.source = lowRes;
                    passData.useDepth = hasDepth;
                    builder.UseTexture(lowRes);
                    if (hasDepth)
                    {
                        passData.depth = resourceData.cameraDepthTexture;
                        builder.UseTexture(passData.depth);
                    }
                    builder.SetRenderAttachment(destination, 0);
                    builder.AllowPassCulling(false);
                    builder.AllowGlobalStateModification(true);
                    builder.SetRenderFunc((PassData data, RasterGraphContext ctx) =>
                    {
                        if (data.useDepth)
                            ctx.cmd.SetGlobalTexture(DepthTexId, data.depth);
                        Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1f, 1f, 0f, 0f), data.material, 0);
                    });
                }

                resourceData.cameraColor = destination;
            }

        }

        PSXPostPass m_Pass;
        Material m_Material;

        public override void Create()
        {
            m_Pass = new PSXPostPass
            {
                renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing
            };
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var mgr = PSXEffectsManager.Active;
            if (mgr == null || !mgr.isActiveAndEnabled)
                return;

            var camType = renderingData.cameraData.cameraType;
            if (camType == CameraType.Preview || camType == CameraType.Reflection)
                return;

            // Vertex snapping icin hedef cozunurlugu her durumda guncelle
            var desc = renderingData.cameraData.cameraTargetDescriptor;
            mgr.PushTargetResolution(mgr.GetTargetResolution(desc.width, desc.height));

            if (!mgr.enablePostProcessing)
                return;
            if (camType == CameraType.SceneView && !mgr.applyInSceneView)
                return;

            if (m_Material == null)
            {
                Shader shader = Shader.Find("Hidden/PSX/PostProcess");
                if (shader == null)
                    return;
                m_Material = CoreUtils.CreateEngineMaterial(shader);
            }

            m_Pass.material = m_Material;
            m_Pass.requiresIntermediateTexture = true;
            renderer.EnqueuePass(m_Pass);
        }

        protected override void Dispose(bool disposing)
        {
            m_Pass?.ReleaseTargets();
            CoreUtils.Destroy(m_Material);
            m_Material = null;
        }
    }
}
