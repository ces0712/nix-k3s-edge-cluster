# Kubernetes at the Edge: NixOS + K3s 🚀

This repository contains the deterministic and declarative configuration for a Kubernetes edge cluster. 

## 📌 Project Overview
Built with **NixOS**, **K3s**, and **Colmena**, this project demonstrates how to eliminate configuration drift at the edge by treating the entire infrastructure as a pure function.

**Target for 2026 Conference Season:**
- 🇦🇷 DevOpsDays Buenos Aires
- 🇺🇸 KCD Texas
- 🇵🇦 KCD Panama

## 🛠 Tech Stack
- **OS:** NixOS (Flakes enabled)
- **K8s:** K3s (Lightweight K8s)
- **Deployment:** Colmena (NixOS Orchestrator)
- **Hardware:** Raspberry Pi (aarch64)

## 📂 Structure
- `hosts/`: Node-specific configurations.
- `modules/`: Reusable NixOS modules for K3s and networking.
- `kubernetes/`: K8s manifests (GitOps style).

## 📅 Status
**Work in Progress.** Architecture diagrams and full Nix Flakes will be published following the conference schedule.
