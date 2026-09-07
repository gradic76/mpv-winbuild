#!/bin/bash
# The Bell: cut ffmpeg and mpv to audio, PCM and MP3 only.
#
# Written as a script rather than a patch on purpose. Measured 2026-09-07:
# seventeen of the fork's eighteen existing patches no longer apply cleanly to
# upstream, and the workflow swallows a failed patch ("git am --3way || git am
# --abort"). A patch of ours would therefore depend on which of theirs happened
# to land that day. This edits whatever tree it finds.
#
# It is noisy on purpose: every change reports whether it took, because a cut
# that silently does nothing produces a full-size build that looks fine until
# someone measures it.
set -u
cd "$(dirname "$0")/mpv-winbuild-cmake" 2>/dev/null || cd mpv-winbuild-cmake 2>/dev/null || true
echo "=== The Bell cut, in $(pwd) ==="

FF=packages/ffmpeg.cmake
MPV=packages/mpv.cmake
[ -f "$FF" ] || { echo "NEMA $FF — odustajem"; exit 1; }
[ -f "$MPV" ] || { echo "NEMA $MPV — odustajem"; exit 1; }

DEC='mp3,mp3adu,mp3adufloat,mp3float,mp3on4,mp3on4float,pcm_alaw,pcm_bluray,pcm_dvd,pcm_dvda,pcm_f16le,pcm_f24le,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_lxf,pcm_mulaw,pcm_s16be,pcm_s16be_planar,pcm_s16le,pcm_s16le_planar,pcm_s24be,pcm_s24daud,pcm_s24le,pcm_s24le_planar,pcm_s32be,pcm_s32le,pcm_s32le_planar,pcm_s64be,pcm_s64le,pcm_s8,pcm_s8_planar,pcm_sga,pcm_u16be,pcm_u16le,pcm_u24be,pcm_u24le,pcm_u32be,pcm_u32le,pcm_u8,pcm_vidc'
ENC='libmp3lame,pcm_alaw,pcm_bluray,pcm_dvd,pcm_f32be,pcm_f32le,pcm_f64be,pcm_f64le,pcm_mulaw,pcm_s16be,pcm_s16be_planar,pcm_s16le,pcm_s16le_planar,pcm_s24be,pcm_s24daud,pcm_s24le,pcm_s24le_planar,pcm_s32be,pcm_s32le,pcm_s32le_planar,pcm_s64be,pcm_s64le,pcm_s8,pcm_s8_planar,pcm_u16be,pcm_u16le,pcm_u24be,pcm_u24le,pcm_u32be,pcm_u32le,pcm_u8,pcm_vidc'
FILT='aap,abench,abuffer,acompressor,acontrast,acopy,acrossfade,acrossover,acrusher,acue,adeclick,adeclip,adecorrelate,adelay,adenorm,aderivative,adrc,adynamicequalizer,adynamicsmooth,aecho,aemphasis,aeval,aevalsrc,aexciter,afade,afdelaysrc,afftdn,afftfilt,afir,afireqsrc,afirsrc,aformat,afreqshift,afwtdn,agate,aiir,aintegral,ainterleave,alatency,alimiter,allpass,aloop,amerge,ametadata,amix,amultiply,anequalizer,anlmdn,anlmf,anlms,anoisesrc,anull,anullsink,anullsrc,apad,aperms,aphaser,aphaseshift,apsnr,apsyclip,apulsator,arealtime,aresample,areverse,arls,arnndn,asdr,asegment,aselect,asendcmd,asetnsamples,asetpts,asetrate,asettb,ashowinfo,asidedata,asisdr,asoftclip,aspectralstats,asplit,asr,astats,astreamselect,asubboost,asubcut,asupercut,asuperpass,asuperstop,atempo,atilt,atrim,axcorrelate,azmq,bandpass,bandreject,bass,biquad,bs2b,channelmap,channelsplit,chorus,compand,compensationdelay,crossfeed,crystalizer,dcshift,deesser,dialoguenhance,drmeter,dynaudnorm,earwax,ebur128,equalizer,extrastereo,firequalizer,flanger,flite,haas,hdcd,headphone,highpass,highshelf,hilbert,join,ladspa,loudnorm,lowpass,lowshelf,lv2,mcompand,pan,replaygain,rubberband,sidechaincompress,sidechaingate,silencedetect,silenceremove,sinc,sine,sofalizer,speechnorm,stereotools,stereowiden,superequalizer,surround,tiltshelf,treble,tremolo,vibrato,virtualbass,volume,volumedetect,whisper'

# ── ffmpeg: dependencies ────────────────────────────────────────────────────
A=$(grep -n "^    DEPENDS$" "$FF" | head -1 | cut -d: -f1)
B=$(grep -n "GIT_REPOSITORY https://github.com/FFmpeg/FFmpeg.git" "$FF" | head -1 | cut -d: -f1)
if [ -n "$A" ] && [ -n "$B" ]; then
  { sed -n "1,${A}p" "$FF"; printf '        bzip2\n        lame\n        zlib\n'; sed -n "${B},\$p" "$FF"; } > /tmp/x && mv /tmp/x "$FF"
  echo "  ffmpeg DEPENDS -> bzip2 lame zlib"
else
  echo "  UPOZORENJE: ffmpeg DEPENDS nije nadjen"
fi

# ── ffmpeg: configure flags ─────────────────────────────────────────────────
A=$(grep -n -- "--enable-gpl" "$FF" | head -1 | cut -d: -f1)
B=$(grep -n -- "--enable-nvdec" "$FF" | head -1 | cut -d: -f1)
if [ -n "$A" ] && [ -n "$B" ]; then
  { sed -n "1,$((A-1))p" "$FF"
    printf '        --disable-everything\n        --enable-libmp3lame\n'
    printf '        --enable-decoder=%s\n        --enable-encoder=%s\n' "$DEC" "$ENC"
    printf '        --enable-demuxer=wav,w64,mp3\n        --enable-muxer=wav,w64,mp3,null\n'
    printf '        --enable-parser=mpegaudio\n        --enable-protocol=file,pipe\n'
    printf '        --enable-filter=%s\n' "$FILT"
    sed -n "$((B+1)),\$p" "$FF"; } > /tmp/x && mv /tmp/x "$FF"
  echo "  ffmpeg configure -> disable-everything + PCM/MP3/filtri"
else
  echo "  UPOZORENJE: ffmpeg configure blok nije nadjen"
fi
for o in nvenc amf openal opengl vaapi cuda-llvm cuvid nvdec avisynth vapoursynth; do
  sed -i "/--enable-$o/d" "$FF"
done

# ── ffmpeg: the arnndn fix ──────────────────────────────────────────────────
if ! grep -q "ffmpeg-\*.patch" "$FF"; then
  awk '/^    UPDATE_COMMAND ""$/ && !d {print "    PATCH_COMMAND ${EXEC} git am --3way ${CMAKE_CURRENT_SOURCE_DIR}/ffmpeg-*.patch"; d=1} {print}' "$FF" > /tmp/x && mv /tmp/x "$FF"
  echo "  ffmpeg PATCH_COMMAND dodan"
fi
cp ../bell-ffmpeg-arnndn.patch packages/ffmpeg-0001-arnndn-short-frame.patch && echo "  arnndn zakrpa kopirana"

# ── mpv: dependencies ───────────────────────────────────────────────────────
A=$(grep -n "^    DEPENDS$" "$MPV" | head -1 | cut -d: -f1)
B=$(grep -n "GIT_REPOSITORY" "$MPV" | head -1 | cut -d: -f1)
if [ -n "$A" ] && [ -n "$B" ]; then
  { sed -n "1,${A}p" "$MPV"
    printf '        ffmpeg\n        libass\n        libplacebo\n        fribidi\n        libiconv\n        libpng\n        harfbuzz\n        freetype2\n        fontconfig\n'
    sed -n "${B},\$p" "$MPV"; } > /tmp/x && mv /tmp/x "$MPV"
  echo "  mpv DEPENDS -> ffmpeg libass libplacebo + njihove"
else
  echo "  UPOZORENJE: mpv DEPENDS nije nadjen"
fi

# ── mpv: options ────────────────────────────────────────────────────────────
# Every -D option that is not ours is turned off by name. Anything left on
# 'auto' turns itself on when the build image happens to have the dependency —
# that is how 43 video options once ended up inside an "audio-only" build.
sed -i '/-D[a-z0-9-]*=enabled/d' "$MPV"
A=$(grep -n -- "-Dlibmpv=true" "$MPV" | head -1 | cut -d: -f1)
if [ -n "$A" ]; then
  { sed -n "1,${A}p" "$MPV"; sed 's/^/        /' ../bell-mpv-options.txt; sed -n "$((A+1)),\$p" "$MPV"; } > /tmp/x && mv /tmp/x "$MPV"
  echo "  mpv opcije -> audio-only ($(wc -l < ../bell-mpv-options.txt) komada)"
fi
sed -i '/^        curl$/d' "$MPV"

# --- mpv: OpenGL, koji se postavlja posve drugdje ---
# mpv.cmake samo razvija ${mpv_gl}; vrijednost se postavlja po arhitekturi u
# cmake/packages_check.cmake, i za x86_64 glasi "-Dgl=enabled -Degl-angle=enabled".
# Izmjereno 2026-09-07: izbaciti angle-headers iz mpv DEPENDS dok to stoji
# ukljuceno je tocno nacin na koji build umre s
# "Feature egl-angle cannot be enabled: egl-angle could not be found".
CHK=cmake/packages_check.cmake
if [ -f "$CHK" ]; then
  sed -i 's/^\( *\)set(mpv_gl .*/\1set(mpv_gl "-Dgl=disabled -Degl-angle=disabled")/' "$CHK"
  echo "  mpv_gl -> gl i egl-angle ugaseni ($(grep -c 'Dgl=disabled' "$CHK") mjesta)"
else
  echo "  UPOZORENJE: nema $CHK, mpv_gl nije diran"
fi

echo ""
echo "=== provjera ==="
grep -q -- "--disable-everything" "$FF" && echo "  OK ffmpeg rezан" || echo "  PALO: ffmpeg nije rezan"
grep -q -- "--enable-libmp3lame" "$FF" && echo "  OK libmp3lame" || echo "  PALO: nema libmp3lame"
grep -q "ffmpeg-0001-arnndn" packages/ffmpeg-0001-arnndn-short-frame.patch 2>/dev/null || \
  ([ -f packages/ffmpeg-0001-arnndn-short-frame.patch ] && echo "  OK arnndn zakrpa na mjestu" || echo "  PALO: nema arnndn zakrpe")
grep -c -- "-Dlibcurl=enabled" "$MPV" | grep -q "^0$" && echo "  OK libcurl ugasen" || echo "  PALO: libcurl jos ukljucen"
grep -rq -- "-Degl-angle=enabled" cmake packages 2>/dev/null && echo "  PALO: egl-angle je jos ukljucen" || echo "  OK egl-angle ugasen"
echo "  preostalih enable-lib u ffmpegu: $(grep -c -- "--enable-lib" "$FF")"
echo "  preostalih =enabled u mpv opcijama: $(grep -c -- "=enabled" "$MPV")"
