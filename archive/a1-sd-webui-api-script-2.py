import json
import requests
import io
import base64
from PIL import Image, PngImagePlugin

url = "http://127.0.0.1:7860"

option_payload1 = {
    "samples_format": "jpg",
    "jpeg_quality": 94,
    "sd_model_checkpoint": "Any-Lora-NoVaeFp16Pruned.ckpt",
    "sd_vae": "anything-v4.0.vae.pt",
    "CLIP_stop_at_last_layers": 2
}

requests.post(url=f'{url}/sdapi/v1/options', json=option_payload1)

encoded1 = base64.b64encode(open("/home/sapien/Downloads/pose_2023_04_10_17_44_27.png", "rb").read())
encoded2 = str(encoded1, encoding='utf-8')
encoded3 = 'data:image/png;base64,' + encoded2

# controlnet args needs a separate {} for each enabled controlnet
txt2img_payload = {
    "prompt": "(masterpiece, best quality), mature female, red bikini, purple hair, purple eyes, short hair, serious, outdoors",
    "negative_prompt": "(worst quality, low quality), blurry, loli, signature, realistic, lip, nose, rouge, lipstick, eyeshadow, censored, [plump]",
    "width": 512,
    "height": 864,
    "sampler_index": "Euler",
    "cfg_scale": 7,
    "steps": 24,
    "save_images": True,
    "alwayson_scripts": {
        "controlnet": {
        "args": [
            {
            "input_image": encoded3,
            "mask": "",
            "module": "none",
            "model": "control_openpose-fp16 [9ca67cc5]",
            "weight": 1.2,
            "resize_mode": "Scale to Fit (Inner Fit)",
            "lowvram": False,
            "processor_res": 64,
            "threshold_a": 64,
            "threshold_b": 64,
            "guidance": 1,
            "guidance_start": 0,
            "guidance_end": 1,
            "guessmode": False
            },
            { "enabled": False }
            ]
        }
    }
}

response1 = requests.post(url=f'{url}/sdapi/v1/txt2img', json=txt2img_payload).json()

# Remove the extra image that controlnet adds
response1['images'].pop()

img2img_payload = {
    "init_images": response1['images'],
    "prompt": txt2img_payload["prompt"],
    "negative_prompt": txt2img_payload["negative_prompt"],
    "width": 1024,
    "height": 1728,
    "sampler_index": "Euler",
    "cfg_scale": 7,
    "steps": 24,
    "denoising_strength": 0.5,
    "save_images": True
}

requests.post(url=f'{url}/sdapi/v1/img2img', json=img2img_payload)


