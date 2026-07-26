from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import imageio.v2 as imageio
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BUNDLE = ROOT / 'evaluation_artifacts' / 'co5_testing_bundle'
SHOTS = BUNDLE / 'outputs' / 'screenshots'
VIDEOS = BUNDLE / 'outputs' / 'videos'

SLIDES = [
    ('CO-5 Testing Evidence', 'real_test.png', 2.5),
    ('TC-01 Positive Login', 'success_login.png', 3.0),
    ('TC-07 Valid Semester Addition', 'success_add_semester.png', 3.0),
    ('TC-06 Negative Login', 'failed_login.png', 3.0),
]

WIDTH, HEIGHT = 1280, 720
FPS = 24


def load_font(size: int):
    candidates = [
        'C:/Windows/Fonts/segoeuib.ttf',
        'C:/Windows/Fonts/arialbd.ttf',
        'C:/Windows/Fonts/arial.ttf',
    ]
    for f in candidates:
        p = Path(f)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def fit_image(img: Image.Image, w: int, h: int) -> Image.Image:
    img = img.convert('RGB')
    src_w, src_h = img.size
    scale = max(w / src_w, h / src_h)
    new_w = int(src_w * scale)
    new_h = int(src_h * scale)
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    left = (new_w - w) // 2
    top = (new_h - h) // 2
    return resized.crop((left, top, left + w, top + h))


def draw_title(frame: Image.Image, title: str):
    draw = ImageDraw.Draw(frame, 'RGBA')
    title_font = load_font(46)
    subtitle_font = load_font(24)

    # Bottom overlay bar for readability
    bar_h = 120
    draw.rectangle([(0, HEIGHT - bar_h), (WIDTH, HEIGHT)], fill=(10, 24, 40, 180))
    draw.text((36, HEIGHT - 92), title, font=title_font, fill=(245, 247, 250, 255))
    draw.text((36, HEIGHT - 48), 'ProfessorOS | CO-5 Evaluation Evidence', font=subtitle_font, fill=(188, 201, 216, 255))


def build_frames(slide_img: Image.Image, title: str, seconds: float):
    n = max(1, int(seconds * FPS))
    frames = []
    for i in range(n):
        t = i / max(1, n - 1)
        # Very light zoom-in effect
        zoom = 1.0 + (0.05 * t)
        zw = int(WIDTH / zoom)
        zh = int(HEIGHT / zoom)
        left = (WIDTH - zw) // 2
        top = (HEIGHT - zh) // 2
        crop = slide_img.crop((left, top, left + zw, top + zh)).resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        draw_title(crop, title)
        frames.append(np.array(crop))
    return frames


def main():
    VIDEOS.mkdir(parents=True, exist_ok=True)

    all_frames = []
    missing = []

    for title, filename, seconds in SLIDES:
        path = SHOTS / filename
        if not path.exists():
            missing.append(str(path))
            continue
        img = Image.open(path)
        fitted = fit_image(img, WIDTH, HEIGHT)
        all_frames.extend(build_frames(fitted, title, seconds))

    if not all_frames:
        raise RuntimeError('No screenshots available to build video.')

    mp4_path = VIDEOS / 'co5_demo_full.mp4'
    gif_path = VIDEOS / 'co5_demo_preview.gif'

    imageio.mimsave(mp4_path, all_frames, fps=FPS)
    imageio.mimsave(gif_path, all_frames, fps=10)

    print(f'MP4 video saved: {mp4_path}')
    print(f'GIF preview saved: {gif_path}')
    if missing:
        print('Missing screenshots:')
        for m in missing:
            print(f' - {m}')


if __name__ == '__main__':
    main()
