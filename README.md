# Antigravity GitHub Actions Terminal (vía sshx)

Terminal web remota colaborativa e instantánea en máquinas virtuales de GitHub Actions usando [sshx](https://sshx.io/).

---

## ⚡ Características
- **Sin cuentas ni tokens**: No necesitas registrarte en ningún servicio.
- **Acceso instantáneo por navegador**: Haz clic en el enlace `https://sshx.io/s/...` y tendrás una terminal bash completa con soporte para `sudo`.
- **Ultra rápido**: Construido en Rust con soporte para múltiples cursores, terminales concurrentes y redimensionado fluido.

---

## 🚀 Cómo Usarlo

1. Ve a la pestaña **Actions** en GitHub: [SlidiePie/github-vm Actions](https://github.com/SlidiePie/github-vm/actions).
2. Selecciona **Antigravity Terminal (sshx)** en la lista de workflows.
3. Haz clic en **Run workflow** (puedes elegir `ubuntu-latest` o `macos-latest`).
4. Abre la ejecución y en unos segundos verás el enlace web en la tarjeta de resumen (**Summary**) o en los logs del paso *Start sshx Web & Remote Terminal*:
   ```text
   https://sshx.io/s/xxxxxxxx#yyyyyyyy
   ```
5. Abre el enlace en tu navegador para empezar a usar la terminal inmediatamente.