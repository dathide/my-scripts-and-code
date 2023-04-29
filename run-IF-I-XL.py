from diffusers import DiffusionPipeline
from diffusers.utils import pt_to_pil
import torch
import gc
import random

# stage 1
stage_1 = DiffusionPipeline.from_pretrained("DeepFloyd/IF-I-XL-v1.0", variant="fp16", torch_dtype=torch.float16)
stage_1.to("cuda")
#stage_1.enable_model_cpu_offload()

prompt = "A cat rhino"
img_count = 4

# text embeds
prompt_embeds, negative_embeds = stage_1.encode_prompt(prompt)

rand_array = [random.randint(10000,99999) for _ in range(img_count)]

s1_images = []

for i in range(img_count):
    generator = torch.manual_seed(rand_array[i])

    image = stage_1(prompt_embeds=prompt_embeds, negative_prompt_embeds=negative_embeds, generator=generator, output_type="pt").images

    s1_images.append(image)

    pt_to_pil(image)[0].save(f"./{rand_array[i]}_s1.png")

# unload stage 1 so we don't run out of VRAM
del stage_1
gc.collect()
torch.cuda.empty_cache()

# stage 2
stage_2 = DiffusionPipeline.from_pretrained(
    "DeepFloyd/IF-II-L-v1.0", text_encoder=None, variant="fp16", torch_dtype=torch.float16
)
stage_2.to("cuda")
#stage_2.enable_model_cpu_offload()

# stage 3
safety_modules = {"feature_extractor": stage_1.feature_extractor, "safety_checker": stage_1.safety_checker, "watermarker": stage_1.watermarker}
stage_3 = DiffusionPipeline.from_pretrained("stabilityai/stable-diffusion-x4-upscaler", **safety_modules, torch_dtype=torch.float16)
stage_3.to("cuda")
#stage_3.enable_model_cpu_offload()

for i in range(img_count):
    generator = torch.manual_seed(rand_array[i])

    image = stage_2(
        image=s1_images[i], prompt_embeds=prompt_embeds, negative_prompt_embeds=negative_embeds, generator=generator, output_type="pt"
    ).images

    pt_to_pil(image)[0].save(f"./{rand_array[i]}_s2.png")

    image = stage_3(prompt=prompt, image=image, generator=generator, noise_level=100).images

    image[0].save(f"./{rand_array[i]}_s3.png")
