"""Offline, neural Mandarin game-voice renderer (no system TTS; no fal.ai).

Run at BUILD TIME, not on mobile. The Apache-2.0 Kokoro v1.1 Chinese model
is fetched once, cached in CI, and discarded after rendering compressed OGGs.
Only neural output audio is distributed in the APK, not the inference weights.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

# Short, hand-authored dialogue to avoid run-time synthesis or latency.
VOICE_LINES = {
    'brief_0': '这里是泽瑞克斯异常调查组。林岚失联已经十二小时。前方建筑在五年前就被拆除了。找到录音，然后离开。',
    'brief_1': '电梯正在下降。这里的管道会重复你的脚步声。林岚的信号仍在更深处。先收集维修记录。',
    'brief_2': '这里是最后一层。水中有不属于你的倒影。录音已经很近了。不要在黑暗中停留。',
    'tape_0_0': '我来到拆除后的工地。里面的灯，还亮着。',
    'tape_0_1': '我听到有人在另一侧模仿我的呼吸。',
    'tape_0_2': '如果你来找我，不要跟着脚步声。',
    'tape_1_0': '地下管线图显示，这里根本没有地下层。',
    'tape_1_1': '回声总比脚步慢半拍。它在学习。',
    'tape_1_2': '我把最后的频率写在电梯门上。',
    'tape_2_0': '水面映出了另一个人。那不是我。',
    'tape_2_1': '别停留在黑暗中。它在等你看清它。',
    'tape_2_2': '带走这些记录。然后，离开。',
    'warning': '别看脚步的方向。先听。',
    'elevator': '录音已恢复。电梯开始下降。',
    'ending': '信号回到地面了。但录音的最后，还留着另一个人的呼吸。',
}


def generate(output: Path, voice_id: str = 'zf_001') -> None:
    import numpy as np
    import soundfile as sf
    from kokoro import KPipeline

    output.mkdir(parents=True, exist_ok=True)
    pipeline = KPipeline(lang_code='z', repo_id='hexgrad/Kokoro-82M-v1.1-zh')
    # Generate each voice fully, never let a failed synthesis silently become
    # missing audio or substitute a phone's built-in TTS engine.
    with tempfile.TemporaryDirectory() as tmp:
        for name, line in VOICE_LINES.items():
            pieces = []
            for _, _, audio in pipeline(line, voice=voice_id, speed=0.90):
                sample = audio.detach().cpu().numpy() if hasattr(audio, 'detach') else np.asarray(audio)
                if sample.size: pieces.append(sample.astype(np.float32).reshape(-1))
            if not pieces: raise RuntimeError(f'Kokoro produced no voice for {name}')
            waveform = np.concatenate(pieces)
            if len(waveform) < 3000: raise RuntimeError(f'Kokoro generated unusually short voice for {name}')
            wav = Path(tmp) / (name + '.wav')
            sf.write(wav, waveform, 24000)
            ogg = output / (name + '.ogg')
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),'-ac','1','-ar','24000','-c:a','libvorbis','-q:a','3',str(ogg)],check=True)
            if ogg.stat().st_size < 1000: raise RuntimeError(f'Invalid TTS audio {ogg}')
            print(f'NEURAL_VOICE {name}: {len(waveform)/24000:.1f}s {ogg.stat().st_size} bytes',flush=True)
    print(f'NEURAL_TTS_PASS {len(VOICE_LINES)} files; Kokoro v1.1 Chinese; no system TTS; no fal.ai')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('output', type=Path)
    ap.add_argument('--voice', default='zf_001')
    args = ap.parse_args()
    generate(args.output, args.voice)
