import os, subprocess
from playwright.sync_api import sync_playwright
os.makedirs('frames', exist_ok=True)
for f in os.listdir('frames'): os.remove('frames/'+f)
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome')
    pg=b.new_page(viewport={'width':1280,'height':720})
    pg.goto('file://'+os.path.abspath('chargement.html')); pg.wait_for_timeout(2500)
    n=int(9.8*30)
    for i in range(n):
        pg.evaluate(f'frame({i/30})')
        pg.screenshot(path=f'frames/f{i:04d}.jpg', type='jpeg', quality=90)
    b.close()
ff='/opt/pw-browsers/ffmpeg-1011/ffmpeg-linux'
subprocess.run([ff,'-y','-framerate','30','-i','frames/f%04d.jpg','-c:v','libx264' ,'-pix_fmt','yuv420p','-crf','20','apercu_chargement.mp4'],capture_output=True)
print(os.path.exists('apercu_chargement.mp4'))
