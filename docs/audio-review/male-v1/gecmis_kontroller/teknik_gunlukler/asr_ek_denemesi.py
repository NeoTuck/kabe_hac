from faster_whisper import WhisperModel
from pathlib import Path
import json,subprocess,numpy as np
model=WhisperModel('work_models/faster-whisper-small',device='cpu',compute_type='int8',cpu_threads=4,local_files_only=True)
p='Hac_Umre_Erkek_Sesler_54/wav/A-U01.2-TR-01.wav'
x=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',p,'-ar','16000','-ac','1','-f','f32le','-']),dtype='<f4')
for offset in range(0,len(x),160000):
 segs,info=model.transcribe(x[offset:offset+160000],language='tr',beam_size=5,temperature=0,condition_on_previous_text=False,without_timestamps=True,word_timestamps=False,no_speech_threshold=None,log_prob_threshold=None)
 print(offset/16000,' '.join(s.text for s in segs),flush=True)
