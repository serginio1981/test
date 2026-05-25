# Generador de Sonidos para Banda

App web autónoma (HTML + JavaScript + Web Audio API, sin dependencias ni *build*) para generar sonidos, ensayar y editar arreglos. Incluye un sintetizador sustractivo, un secuenciador con la canción **«Estrechez de Corazón»** (Los Prisioneros) precargada y un teclado tocable.

**Demo en vivo:** https://serginio1981.github.io/test/band-sound-generator/

## Funciones

- **Sintetizador sustractivo** por instrumento: osciladores en unísono (sierra, cuadrada, triangular, senoidal), filtro pasa-bajos con envolvente, envolvente ADSR de amplitud y bus de delay estéreo compartido.
- **Secuenciador** de 32 pasos (4 compases en 4/4) con planificador *lookahead* sobre el reloj del `AudioContext`. Pistas de bajo, *lead* y *pad* de acordes.
- **Editor tipo piano roll** para bajo y *lead*; selector de acorde por compás (Em, C, G, D, Am, Bm, etc.).
- **Teclado tocable** con ratón, pantalla táctil o teclado del PC.
- **Persistencia** automática de la canción y los *patches* en `localStorage`. Botón «Restablecer» para volver al estado original.
- **Login con Google** (opcional) antes de entrar al estudio, con tu nombre y foto visibles en la cabecera.

## Uso rápido

### En la web

Abre la [demo en vivo](https://serginio1981.github.io/test/band-sound-generator/) y toca/pulsa la pantalla una vez para que el navegador autorice el audio.

### En local

No requiere instalación. Dos opciones:

```bash
# 1) Abrir el archivo directamente
open band-sound-generator/index.html        # macOS
xdg-open band-sound-generator/index.html    # Linux
start band-sound-generator/index.html       # Windows

# 2) Servir con un servidor estático
cd band-sound-generator
python3 -m http.server 8000
# luego visita http://localhost:8000
```

## Controles

| Acción                       | Cómo                                                                       |
| ---------------------------- | -------------------------------------------------------------------------- |
| Reproducir / detener         | Botón ▶ Reproducir · barra espaciadora                                     |
| Editar notas                 | Clic en cualquier celda del piano roll (toca para añadir, otra vez para quitar) |
| Cambiar acorde del compás    | Menú desplegable bajo «Acordes»                                            |
| Tocar el teclado             | Ratón/toque · fila `Z X C…` octava baja · fila `Q W E…` octava alta        |
| Cambiar octava               | Botones «– Octava / Octava +» o flechas `← →`                              |
| Silenciar / limpiar pista    | Botones de cada pista                                                      |
| Editar timbre                | Pestañas Teclado / Bajo / Lead / Acordes en el panel «Sintetizador»        |

## Arquitectura

```
band-sound-generator/
├── index.html
├── css/
│   └── style.css
└── js/
    ├── synth.js       # AudioEngine + clase Synth (voces, envolventes, filtro, delay)
    ├── song.js        # Datos de la canción, biblioteca de acordes y patches por defecto
    ├── sequencer.js   # Planificador con lookahead y cola de pasos visibles
    ├── app.js         # Interfaz: piano roll, acordes, panel de síntesis, teclado, persistencia
    └── auth.js        # Login con Google Identity Services (opcional, configurable)
```

Los scripts se cargan como *classic scripts* (no módulos ES), por lo que la app también funciona abriéndola con `file://` sin servidor.

## Despliegue

El despliegue a GitHub Pages está automatizado en `.github/workflows/static.yml` (en la rama por defecto del repositorio); se ejecuta en cada *push* y publica el contenido del repo.

## Configurar el login de Google

La app incluye una pantalla de inicio de sesión con Google (Google Identity Services). **Por defecto está desactivada** (modo desarrollo): mientras `GOOGLE_CLIENT_ID` esté vacío en `js/auth.js`, la app arranca sin pedir login.

> **Aviso:** como esta app es 100 % cliente sin backend, el login es una **puerta cosmética**. Sirve para identificar a quien entra y mostrar su nombre, pero un usuario técnico puede saltársela editando el navegador. Para una protección real haría falta verificar el token de Google en un servidor.

### Pasos para activarlo

1. Entra en https://console.cloud.google.com/ y crea (o selecciona) un proyecto.
2. **APIs & Services → OAuth consent screen**:
   - *User Type:* **External**.
   - Rellena nombre de la app, email de soporte y de contacto del desarrollador.
   - *Scopes:* por defecto basta con `openid`, `email`, `profile`.
   - *Publishing status:* deja **Testing** mientras pruebas; añade los emails que vayan a entrar como *Test users*. Cuando quieras dejarlo abierto a cualquier cuenta, pulsa **Publish app**.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - *Application type:* **Web application**.
   - *Authorized JavaScript origins* — añade:
     - `https://serginio1981.github.io`
     - `http://localhost:8000` (o el puerto que uses en local)
   - *Authorized redirect URIs:* no hace falta — Google Identity Services funciona sin redirecciones para este flujo.
4. Copia el **Client ID** (algo como `1234567890-abcdef.apps.googleusercontent.com`).
5. Pégalo en `band-sound-generator/js/auth.js`:
   ```js
   const GOOGLE_CLIENT_ID = '1234567890-abcdef.apps.googleusercontent.com';
   ```
6. Confirma los cambios y vuelve a desplegar (basta con un `git push`).

A partir de ese momento la app mostrará la pantalla de login antes de entrar al estudio. Tu sesión se recuerda en `localStorage` hasta que el token expire (~1 hora) o pulses «Salir».

## Sobre la canción

«Estrechez de Corazón» es una composición de **Los Prisioneros**. La transcripción cargada por defecto es una **interpretación de partida** (progresión Em – C – G – D en Mi menor); todas las notas se pueden ajustar desde el piano roll y se guardan automáticamente en el navegador.
