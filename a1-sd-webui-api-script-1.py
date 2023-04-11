import json
import requests
import io
import base64
#from PIL import Image, PngImagePlugin

url = "http://127.0.0.1:7860"

option_payload = {
    "samples_format": "jpg",
    "jpeg_quality": 94,
    "sd_model_checkpoint": "Any-Lora-NoVaeFp16Pruned.ckpt",
    "sd_vae": "anything-v4.0.vae.pt",
    "CLIP_stop_at_last_layers": 2
}

txt2img_payload = {
    "prompt": "(masterpiece, best quality), mature female, red bikini, purple hair, purple eyes, short hair, serious, outdoors",
    "negative_prompt": "(worst quality, low quality), blurry, loli, signature, realistic, lip, nose, rouge, lipstick, eyeshadow, censored, [plump]",
    "width": 512,
    "height": 864,
    "sampler_index": "Euler",
    "cfg_scale": 7,
    "steps": 20,
    "save_images": False
}

requests.post(url=f'{url}/sdapi/v1/options', json=option_payload)

response1 = requests.post(url=f'{url}/sdapi/v1/txt2img', json=txt2img_payload).json()

img2img_payload = {
    "init_images": response1['images'],
    "prompt": txt2img_payload["prompt"],
    "negative_prompt": txt2img_payload["negative_prompt"],
    "width": 1024,
    "height": 1728,
    "sampler_index": "Euler",
    "cfg_scale": 7,
    "steps": 20,
    "denoising_strength": 0.5,
    "save_images": True
}

requests.post(url=f'{url}/sdapi/v1/img2img', json=img2img_payload)
