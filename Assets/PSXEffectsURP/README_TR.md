# PSX Effects URP

PlayStation 1 tarzı render paketi — orijinal **PSXEffects** (Built-in RP) paketinin
Unity 6 / URP 17 için **sıfırdan yazılmış** sürümü. Mantık aynı, mimari modern:
Render Graph tabanlı renderer feature + URP Volume entegrasyonu.

Referans: [david-colson.com — PS1 Style Renderer](https://www.david-colson.com/2021/11/30/ps1-style-renderer.html)

---

## Hızlı Kurulum (tak-çalıştır)

1. `Prefabs/PSX Effects` prefabını sahneye sürükleyin. **Bu kadar.**
   - Editor otomatik olarak URP renderer'ına `PSX Render Feature`'ı ekler.
   - `Settings/PSX Post Profile.asset` volume profili oluşturulur ve prefaba global Volume olarak bağlanır.
2. Materyallerinizde `PSX/Lit` shader'ını kullanın.
   - Toplu dönüştürme: materyalleri seçin → **Tools → PSX Effects → Seçili Materyalleri PSX-Lit'e Dönüştür**.
3. Manuel kurulum gerekirse: **Tools → PSX Effects → Sahneye Kur**.

> Işıksız (%99 PS1 oyunu gibi) bir görünüm için materyalde **Unlit** açın ve
> sahnenizi vertex color ile boyayın — orijinal paketle aynı mantık.

---

## Bileşenler

### PSX Effects Manager (`PSX Effects` objesi)
Geometri/kamera efektleri — global shader değişkenleriyle tüm PSX/Lit materyallerini yönetir:

| Ayar | Açıklama | Orijinal karşılığı |
|---|---|---|
| Resolution Mode / Fixed 320x240 | Düşük çözünürlük hedefi (Match Aspect: 16:9'da 426x240) | Custom Resolution / Resolution Factor |
| Frame Hold | Görüntüyü N kare tutar | Frame Skip |
| Target Frame Rate | FPS sınırı | Target Framerate |
| Vertex Snapping + Snap Amount | Poligon titremesi (0-1 şiddet — yeni) | Vertex Inaccuracy |
| World Space Snapping | Dünya uzayında snap | Use World Space Snapping |
| Affine Amount | Doku kayması şiddeti 0-1 (yeni: kademeli) | Affine Texture Mapping |
| Draw Distance | Poligon çizim mesafesi | Polygonal Draw Distance |
| PSX Style Shadows | Çıkarımsal (subtractive) gölge | Shadow Type: PSX |
| Camera Snapping | Kamera pozisyon titremesi (parent hilesi olmadan) | Camera Inaccuracy |

### PSX Post Process (Volume override)
Volume profilinde **PSX → PSX Post Process**:

- **Color Depth** (5 = 15-bit PS1), **Dither Intensity** (gerçek PS1 4x4 GPU matrisi), **Dither Sky**
- **Favor Red / Subtract Fade** (orijinal ton ayarları)
- **Scanline**, **Interlacing** *(yeni)*, **CRT Curvature** *(yeni)*, **Vignette** *(yeni)*

Volume yoksa bile klasik PS1 varsayılanları otomatik uygulanır.
Sahne bazlı geçişler için local Volume'lar kullanabilirsiniz.

### PSX/Lit Shader
- Render Mode: Opaque / Cutout / Transparent, Blend Op (Add/Subtract/RevSubtract — PSX gölge materyalleri için)
- Ignore Depth Buffer, Backface Culling, Unlit, Vertex Colors
- Diffuse Model: Vertex (Gouraud) / Fragment; Specular: Gouraud / Phong
- Normal Map, Specular Map, Emission, Cubemap (sahte env-map)
- LOD Texture + LOD Distance: mesafeye göre düşük çözünürlüklü dokuya geçiş (orijinaldeki gibi)
- **Texture Color Quantization** *(yeni)*: doku örneklemede bit kırpma (CLUT hissi)
- **Vertex Snap Scale** ve **Affine Override**: materyal bazlı geçersiz kılma
- Lightmap, ana ışık gölgeleri, ek ışıklar (Forward ve Forward+/Cluster), sis desteği

## Orijinalden farklar / iyileştirmeler

- `OnRenderImage` yerine **Render Graph** (Unity 6 uyumlu, Compatibility Mode yedekli).
- Post ayarları **URP Volume** sistemine taşındı (sahne geçişleri, blend).
- Vertex snap artık makaledeki gibi **hedef çözünürlük gridine** yapılır (çözünürlükle tutarlı titreme).
- Affine mapping 0-1 kademeli; aşırı kayan yüzeyler için materyal bazlı düşürülebilir.
- Dither doku dosyası gerekmez; PS1'in gerçek 4x4 matrisi shader içinde.
- Kamera snap parent objesi oluşturmadan, delta takibiyle çalışır.
- Yeni: interlacing, CRT bombeleme, vignette, texture quantization, materyal dönüştürücü.
- Bilinçli çıkarılanlar: Metal doku (PS1 dönemiyle çelişiyor; ihtiyaç olursa eklenebilir), otomatik güncelleme denetimi.

## Notlar

- URP asset'inizde **Depth Texture** açık olmalı (Dither Sky = kapalı kullanılacaksa). Projenizde zaten açık.
- Renderer **Forward+** modunda ek ışıklar cluster döngüsüyle hesaplanır; tam Gouraud nokta ışıkları için Forward modu da kullanabilirsiniz.
- Affine kayması aşırıysa: poligonları bölün (orijinal dökümandaki tavsiye) veya Affine Amount'u düşürün.
