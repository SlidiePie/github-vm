# Antigravity GitHub Actions SSH Server

Servidor **OpenSSH nativo** en GitHub Actions (Ubuntu / macOS) para conectarse remotamente con **Antigravity** o cualquier cliente SSH.

---

## ⚡ Características
- **Servidor OpenSSH nativo** en el puerto 22.
- **Túnel inteligente**: Soporta **ngrok** (con secret `NGROK_AUTH_TOKEN`) y **Pinggy** (automático, sin necesidad de tokens).
- **Acceso sudo completo** sin contraseña para el usuario `runner`.
- **Información visible**: La IP, puerto y comando de conexión se imprimen en el Step Summary de GitHub Actions.

---

## 🚀 Cómo Iniciar el Servidor SSH

1. Ve a la pestaña **Actions** en GitHub: [SlidiePie/github-vm Actions](https://github.com/SlidiePie/github-vm/actions).
2. Selecciona **Antigravity SSH Server**.
3. Haz clic en **Run workflow**.
   - Puedes seleccionar el sistema operativo (`ubuntu-latest` o `macos-latest`).
   - Puedes cambiar la contraseña si lo deseas (por defecto: `antigravity`).
4. Espera unos segundos a que inicie el paso *Start SSH Tunnel*.

---

## 🔗 Cómo Conectarte

En la pestaña **Summary** de la ejecución en GitHub Actions verás los datos generados:

### 1. Conexión rápida por Terminal
```bash
ssh runner@<HOST> -p <PUERTO>
```
*Contraseña:* `antigravity`

### 2. Configuración en Antigravity (`~/.ssh/config`)
Agrega lo siguiente en tu archivo `C:\Users\Ivo\.ssh\config`:

```ssh-config
Host github-vm
    HostName <HOST>
    Port <PUERTO>
    User runner
```

Luego desde Antigravity: `Ctrl+Shift+P` -> **Remote-SSH: Connect to Host...** -> Selecciona `github-vm`.