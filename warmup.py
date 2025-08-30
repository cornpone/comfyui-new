import torch

try:
    if torch.cuda.is_available():
        print("CUDA is available, running warmup.")
        torch.set_float32_matmul_precision("high")
        dev = "cuda"
        for s in [(1,4,1024,1024), (1,4,1536,1024)]:
            x = torch.randn(*s, device=dev)
            w = torch.randn(4,4,3,3, device=dev)
            y = torch.nn.functional.conv2d(x, w, padding=1)
            _ = y.mean()
        print("GPU Warmup done.")
    else:
        print("CUDA not available, skipping GPU warmup.")
except Exception as e:
    print(f"An error occurred during warmup: {e}")

