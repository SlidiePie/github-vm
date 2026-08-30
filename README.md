# Antigravity GitHub Actions SSH Server

Este repositorio te permite iniciar una máquina virtual (Linux Ubuntu o macOS) en GitHub Actions con un servidor **OpenSSH nativo** expuesto a través de **ngrok**, ideal para conectarte remotamente con **Antigravity** o terminal SSH.

---

## 🚀 Configuración Inicial (Solo 1 vez)

1. **Obtén tu token de ngrok**:
   - Regístrate gratis en [ngrok.com](https://ngrok.com).
   - Ve a [Your Authtoken](https://dashboard.ngrok.com/get-started/your-authtoken) y copia el token.

2. **Agrega el Secret en GitHub**:
   - En tu repositorio de GitHub, ve a **Settings** > **Secrets and variables** > **Actions**.
   - Haz clic en **New repository secret**.
   - Nombre: `NGROK_AUTH_TOKEN`
   - Valor: *(pega tu token de ngrok)*
   - *(Opcional)* Puedes agregar `SSH_PASSWORD` si deseas fijar una contraseña predeterminada diferente a `antigravity`, o `SSH_PUBLIC_KEY` para autenticación con clave pública.

---

## 💻 Cómo Iniciar el Servidor SSH

1. Ve a la pestaña **Actions** en tu repositorio de GitHub.
2. Selecciona **Antigravity SSH Server** en la lista de workflows a la izquierda.
3. Haz clic en **Run workflow**.
   - Puedes seleccionar el sistema operativo (`ubuntu-latest` o `macos-latest`).
   - Puedes elegir el tiempo de duración (hasta 6 horas).
4. Espera a que el paso **Start ngrok SSH Tunnel** se ejecute (tarda ~15-20 segundos).

---

## 🔗 Cómo Conectarte desde Antigravity / SSH

En la página de ejecución de GitHub Actions, verás una tarjeta en el resumen (**Summary**) con los datos de conexión:

### Opción 1: Comando directo por Terminal
```bash
ssh runner@0.tcp.ngrok.io -p <PUERTO>
```
*Contraseña por defecto:* `antigravity`

### Opción 2: Configuración en Antigravity / VS Code (`~/.ssh/config`)
Agrega lo siguiente a tu archivo `~/.ssh/config`:

```ssh-config
Host github-vm
    HostName 0.tcp.ngrok.io
    Port <PUERTO>
    User runner
```

Luego en Antigravity abre la paleta de comandos (`Ctrl+Shift+P` / `Cmd+Shift+P`) -> **Remote-SSH: Connect to Host...** -> Selecciona `github-vm`.

---

## 🛠 Características
- **Ubuntu Linux (por defecto)** o **macOS**.
- Usuario `runner` con permisos completos de `sudo` sin contraseña.
- Sesión mantenida activa durante todo el tiempo seleccionado (hasta 6 horas).
- Soporte para claves públicas SSH mediante secret `SSH_PUBLIC_KEY`.