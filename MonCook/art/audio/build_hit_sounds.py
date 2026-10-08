"""Author three short original, non-gore impact samples; upload IDs remain a Studio task."""
from pathlib import Path
import math, random, struct, wave
p=Path(__file__).resolve().parent
rng=random.Random(1408)
for name,seconds,mode in [('BodyHit',.14,0),('HornHit',.18,1),('HeavyHit',.23,2)]:
 samples=[];rate=44100
 for i in range(int(rate*seconds)):
  t=i/rate;attack=min(1,t/.003)
  if mode==1: value=(math.sin(2*math.pi*1900*t)+.5*math.sin(2*math.pi*3270*t)+.3*math.sin(2*math.pi*5100*t))*math.exp(-t*35)*.35
  else:value=(math.sin(2*math.pi*(130 if mode==0 else 85)*t)*.6+(rng.random()*2-1)*.25)*math.exp(-t*(32 if mode==0 else 20))
  samples.append(struct.pack('<h',round(max(-.9,min(.9,value*attack))*32767)))
 with wave.open(str(p/(name+'.wav')),'wb') as out:
  out.setnchannels(1);out.setsampwidth(2);out.setframerate(rate);out.writeframes(b''.join(samples))
print('Authored BodyHit/HornHit/HeavyHit WAV files')
