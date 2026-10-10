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
    'brief_0': '这里是泽瑞克斯异常建筑调查组。银杏街十七号，五年前已被拆除。林岚的讯号却还在这里。你已进入建筑内部，先调查失踪的原因。',
    'brief_1': '你们不是第一次来到这里。机器的记录出现了第三名队员，但她的名字不在名单上。小心和你同步的脚步。',
    'brief_2': '最后一层，水会记住每一个人。找到三条记录后，再决定：把证据带出去，还是让信号永远沉默。',
    'tape_0_0': '这栋楼五年前就拆了。可消防验收签字，竟然是昨天。',
    'tape_0_1': '雨水往墙里流。另一串鞋印和你一模一样，却正朝你走来。',
    'tape_0_2': '调度单上有你两次签名。第一次写着，已经返回。第二次写着，再次进入。',
    'tape_1_0': '供水阀的编号，指向城市图纸上不存在的楼层。',
    'tape_1_1': '电机已经停了，第三个麦克风里仍然有呼吸声。',
    'tape_1_2': '电梯里出现了第三个人。她穿着你的制服，胸牌却写着林岚。',
    'tape_2_0': '林岚的工牌还是湿的。签发日期是明天。',
    'tape_2_1': '这是我第七次来到这里。如果你听到这段话，就证明我又失败了。',
    'tape_2_2': '这不是求救，是警告。千万不要替我打开门。',
    'turn_0': '应急出口的位置已经改变。请不要相信第二次出现的指示牌。',
    'turn_1': '我看到你了，可你明明还在上一层。别回答另一个你的呼叫。',
    'turn_2': '上传通道已连接。警告，记录中包含尚未发生的事件。',
    'warning': '别看脚步的方向。先听。',
    'elevator': '信号已恢复。电梯正在运行。',
    'ending': '信号回到地面。但最后的录音，留下了另一个人的呼吸。',
    'ending_seal': '中继已断开。也许这次，雨水终于不会再到地面。',
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
