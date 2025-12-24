<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/AMD-RX_9070_XT-ED1C24?style=for-the-badge&logo=amd&logoColor=white" alt="AMD">
  <img src="https://img.shields.io/badge/ROCm-7.1.1-EE0000?style=for-the-badge&logo=amd&logoColor=white" alt="ROCm">
  <img src="https://img.shields.io/badge/PyTorch-Nightly-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white" alt="PyTorch">
</p>

<h1 align="center">🎨 ComfyUI Installer for AMD RX 9070 XT</h1>

<p align="center">
  <b>One-click installation script for ComfyUI with full RDNA 4 / gfx120X support on Ubuntu 24.04 LTS</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-stable-brightgreen?style=flat-square" alt="Status">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white" alt="Shell">
  <img src="https://img.shields.io/badge/idempotent-yes-success?style=flat-square" alt="Idempotent">
</p>

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔄 **Idempotent** | Safe to run multiple times - only installs what's missing |
| 🚀 **RDNA 4 Optimized** | Uses AMD's official gfx120X nightly PyTorch builds |
| 📦 **Complete Stack** | Installs drivers, ROCm, PyTorch, ComfyUI, and Manager |
| 🔧 **Auto-Detection** | Checks existing installations and updates only when needed |
| 📜 **Launch Scripts** | Creates ready-to-use scripts with optimal settings |

---

## 📋 What Gets Installed

| Component | Version | Description |
|:---------:|:-------:|:------------|
| <img src="https://img.shields.io/badge/-AMDGPU_DKMS-ED1C24?style=flat-square&logo=amd&logoColor=white" alt="AMDGPU"> | 7.1.1 | Kernel-level GPU driver for RDNA 4 |
| <img src="https://img.shields.io/badge/-ROCm-EE0000?style=flat-square&logo=amd&logoColor=white" alt="ROCm"> | 7.1.1 | Full AMD compute stack (HIP, libraries, OpenCL) |
| <img src="https://img.shields.io/badge/-PyTorch-EE4C2C?style=flat-square&logo=pytorch&logoColor=white" alt="PyTorch"> | Nightly | Experimental gfx120X builds for RDNA 4 |
| <img src="https://img.shields.io/badge/-ComfyUI-5C5C5C?style=flat-square&logo=github&logoColor=white" alt="ComfyUI"> | Latest | Powerful node-based UI for Stable Diffusion |
| <img src="https://img.shields.io/badge/-Manager-5C5C5C?style=flat-square&logo=github&logoColor=white" alt="Manager"> | Latest | Easy node/model management |

---

## 💻 Requirements

| Requirement | Details |
|-------------|---------|
| 🖥️ **OS** | Ubuntu 24.04.3 LTS (Noble Numbat) |
| 🎮 **GPU** | AMD Radeon RX 9070 XT (RDNA 4 / gfx120X) |
| 🔑 **Privileges** | Sudo access required |
| 🌐 **Internet** | Required for downloads |
| 💾 **Storage** | ~15GB free space recommended |
| ⏱️ **Time** | 30-60 minutes for full installation |

---

## 🚀 Quick Start

### 1️⃣ Clone this repository

```bash
git clone https://github.com/Jobar86/comfyui-with-9070xt.git
cd comfyui-rx9070xt-install
```

### 2️⃣ Make the script executable & run

```bash
chmod +x install_comfyui_rx9070xt.sh
./install_comfyui_rx9070xt.sh
```

### 3️⃣ Reboot your system (required!)

```bash
sudo reboot
```

### 4️⃣ Launch ComfyUI

```bash
~/ComfyUI/run_comfyui.sh
```

### 5️⃣ Open your browser

Navigate to **http://127.0.0.1:8188** 🎉

---

## 📁 Directory Structure

After installation, your ComfyUI directory will look like this:

```
~/ComfyUI/
├── 📄 main.py                  # ComfyUI entry point
├── 🚀 run_comfyui.sh           # Main launch script
├── 💾 run_comfyui_lowvram.sh   # Low VRAM mode script
├── 🔄 update_comfyui.sh        # Update script
├── 📦 venv/                    # Python virtual environment
├── 🧩 custom_nodes/
│   └── ComfyUI-Manager/        # Node manager
└── 🎨 models/
    ├── checkpoints/            # SD/SDXL/Flux models
    ├── vae/                    # VAE models
    ├── loras/                  # LoRA models
    ├── controlnet/             # ControlNet models
    ├── upscale_models/         # Upscaler models
    ├── embeddings/             # Textual inversions
    ├── clip/                   # CLIP models
    ├── clip_vision/            # CLIP Vision models
    ├── diffusion_models/       # Diffusion models
    └── text_encoders/          # Text encoder models
```

---

## 🎛️ Launch Options

### Standard Launch
```bash
~/ComfyUI/run_comfyui.sh
```

### Low VRAM Mode
For memory-constrained scenarios:
```bash
~/ComfyUI/run_comfyui_lowvram.sh
```

### Additional Flags
```bash
# Listen on all interfaces (for network access)
~/ComfyUI/run_comfyui.sh --listen 0.0.0.0

# Use a different port
~/ComfyUI/run_comfyui.sh --port 8080

# Enable high VRAM mode for large models
~/ComfyUI/run_comfyui.sh --highvram
```

---

## 🔄 Updating

Keep everything up-to-date with the included update script:

```bash
~/ComfyUI/update_comfyui.sh
```

This updates:
- ✅ ComfyUI core
- ✅ ComfyUI-Manager
- ✅ PyTorch nightly builds
- ✅ Python dependencies

---

## ⚙️ Environment Variables

The script configures these environment variables for optimal RDNA 4 performance:

| Variable | Value | Purpose |
|:--------:|:-----:|:--------|
| `HSA_OVERRIDE_GFX_VERSION` | `12.0.0` | Ensures RDNA 4 compatibility |
| `HIP_VISIBLE_DEVICES` | `0` | Specifies which GPU to use |
| `PYTORCH_TUNABLEOP_ENABLED` | `1` | Enables kernel autotuning |
| `TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL` | `1` | Enables memory-efficient attention |

---

## ✅ Verifying Installation

After reboot, verify your setup:

```bash
# Check ROCm installation
rocminfo

# Check GPU detection
rocm-smi

# Monitor GPU in real-time
watch -n 1 rocm-smi
```

---

## 🔧 Troubleshooting

<details>
<summary><b>🔴 GPU Not Detected After Reboot</b></summary>

1. Ensure user is in correct groups:
   ```bash
   groups $USER
   # Should include: render video
   ```

2. If not, add manually and reboot:
   ```bash
   sudo usermod -a -G render,video $USER
   sudo reboot
   ```
</details>

<details>
<summary><b>🔴 PyTorch Not Using GPU</b></summary>

1. Verify PyTorch sees the GPU:
   ```bash
   source ~/ComfyUI/venv/bin/activate
   python -c "import torch; print(torch.cuda.is_available())"
   ```

2. If false, try reinstalling PyTorch:
   ```bash
   pip uninstall torch torchvision torchaudio
   pip install --pre torch torchvision torchaudio --index-url https://rocm.nightlies.amd.com/v2/gfx120X-all/
   ```
</details>

<details>
<summary><b>🔴 "HSA Error" or "HIP Error"</b></summary>

This usually indicates driver issues. Try:
```bash
# Reinstall AMDGPU driver
sudo amdgpu-install --usecase=rocm -y
sudo reboot
```
</details>

<details>
<summary><b>🔴 Slow Performance</b></summary>

1. Enable tunable ops (first run will be slow):
   ```bash
   export PYTORCH_TUNABLEOP_ENABLED=1
   ```

2. Ensure experimental attention is enabled:
   ```bash
   export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
   ```
</details>

<details>
<summary><b>🔴 Out of Memory Errors</b></summary>

Use the low VRAM launch script:
```bash
~/ComfyUI/run_comfyui_lowvram.sh
```

Or add `--cpu-vae` flag:
```bash
~/ComfyUI/run_comfyui.sh --lowvram --cpu-vae
```
</details>

---

## ⚠️ Known Limitations

> [!WARNING]
> This script uses **nightly PyTorch builds** which may have occasional bugs

| Limitation | Details |
|------------|---------|
| 🧪 Experimental PyTorch | RDNA 4 support is via nightly builds - run updates regularly |
| ⏳ First Launch | Initial generation is slow due to kernel compilation/tuning |
| 🧩 Extension Compatibility | Not all ComfyUI extensions may work perfectly with ROCm |

---

## 🔗 Useful Links

| Resource | Link |
|----------|------|
| 🎨 ComfyUI | [github.com/comfyanonymous/ComfyUI](https://github.com/comfyanonymous/ComfyUI) |
| 📦 ComfyUI-Manager | [github.com/Comfy-Org/ComfyUI-Manager](https://github.com/Comfy-Org/ComfyUI-Manager) |
| 📚 ROCm Documentation | [rocm.docs.amd.com](https://rocm.docs.amd.com/) |
| 🔥 PyTorch ROCm | [pytorch.org/get-started](https://pytorch.org/get-started/locally/) |
| 🌙 AMD Nightly Builds | [rocm.nightlies.amd.com](https://rocm.nightlies.amd.com/) |

---

## 📜 License

This installation script is provided as-is under the **GPL-3.0** license, same as ComfyUI.

---

<p align="center">
  <sub>Created with ❤️ for the AMD RDNA 4 community</sub><br>
  <sub>December 2024</sub>
</p>
