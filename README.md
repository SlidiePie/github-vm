# Antigravity GitHub Actions SSH Server (vía tmate)

Acceso SSH y Web Terminal instantáneo a máquinas virtuales de GitHub Actions (Ubuntu / macOS) utilizando [tmate](https://tmate.io/).

---

## ⚡ Ventajas
- **Sin tokens ni secrets**: No requiere cuenta en ngrok ni tokens de autenticación.
- **Sin contraseñas**: La conexión SSH utiliza claves de sesión seguras automáticas.
- **Terminal Web incluida**: Si no quieres usar un cliente SSH, puedes abrir la sesión directamente en cualquier navegador web.
- **Compatible con Linux y macOS**.

---

## 🚀 Cómo Iniciar la Sesión

1. Ve a la pestaña **Actions** en tu repositorio: [SlidiePie/github-vm Actions](https://github.com/SlidiePie/github-vm/actions).
2. Selecciona **Antigravity SSH Server (tmate)** en el menú izquierdo.
3. Haz clic en **Run workflow**.
   - Puedes seleccionar el sistema operativo (`ubuntu-latest` o `macos-latest`).
4. Espera unos segundos y entra a la ejecución.

---

## 🔗 Cómo Conectarte

En los logs del paso **Start tmate SSH & Web Terminal** (o en el **Summary** de la ejecución), verás los enlaces generados automáticamente:

### 1. Conexión SSH (Terminal / Antigravity):
```bash
ssh <ID_DE_SESION>@<REGION>.tmate.io
```
*(No te pedirá contraseña).*

### 2. Conexión por Terminal Web:
```text
https://tmate.io/t/<ID_DE_SESION>
```
*(Puedes hacer clic y usar la terminal completa directamente en tu navegador).*