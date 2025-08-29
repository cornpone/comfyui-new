import torch
torch.set_float32_matmul_precision("high")
dev = "cuda" if torch.cuda.is_available() else "cpu"
for s in [(1,4,1024,1024), (1,4,1536,1024)]:
    x = torch.randn(*s, device=dev)
    w = torch.randn(4,4,3,3, device=dev)
    y = torch.nn.functional.conv2d(x, w, padding=1)
    _ = y.mean()
print("Warmup done.")
