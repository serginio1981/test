# J.A.R.V.I.S. — asistente de voz para iOS

Asistente de voz personal inspirado en J.A.R.V.I.S. de Iron Man. App nativa
SwiftUI (iOS 17+) que escucha el wake word **«Jarvis»**, transcribe tu orden,
la envía a la **API de Claude** (Anthropic) y responde en voz alta con tono de
mayordomo británico, sobre una interfaz HUD con reactor arc animado.

## Qué puede hacer

- **Conversación por voz**: di «Jarvis» (o toca el reactor) y habla; la
  respuesta se lee en voz alta y queda en el historial.
- **Herramientas** (Claude decide cuándo usarlas):
  - Hora y fecha actuales — «¿qué hora es?»
  - Tiempo actual vía [Open-Meteo](https://open-meteo.com) — «¿qué tiempo hace?»
  - Crear recordatorios (app Recordatorios) — «recuérdame llamar a mamá mañana a las nueve»
  - Abrir páginas web — «abre google.com»
  - **Correo de Outlook** (leer y enviar) — «¿tengo correos nuevos?», «envía un correo a Ana» (requiere configurar Azure, ver abajo)
  - **Apple Music** — «pon Back in Black», «música de Queen», «pausa», «siguiente» (requiere suscripción a Apple Music)
  - **WhatsApp** — «envía un WhatsApp a Juan diciendo que llego tarde»: busca a Juan en tus contactos y abre WhatsApp con el mensaje escrito; tú pulsas enviar (WhatsApp no permite envío automático en cuentas personales)
  - **Uber** — «pide un Uber al aeropuerto»: abre Uber con el destino fijado; tú confirmas el viaje
- **HUD estilo Iron Man**: reactor arc dibujado con Canvas que cambia de color
  según el estado (azul escuchando, dorado pensando, cian hablando) y pulsa
  con tu voz.

> ⚠️ Limitación de iOS: el wake word solo funciona **con la app abierta**.
> Apple no permite a apps de terceros escuchar en segundo plano ni sustituir a Siri.

## Requisitos

- Mac con Xcode 15 o superior.
- iPhone con iOS 17+ (recomendado; el simulador vale para la UI, pero el
  micrófono y el wake word solo son realistas en un dispositivo físico).
- Una clave de API de Anthropic ([console.anthropic.com](https://console.anthropic.com)).

## Instalar sin Mac (Windows + Sideloadly)

No hace falta Mac: cada push a la rama del proyecto (o el botón *Run workflow*)
hace que **GitHub Actions compile un `Jarvis.ipa` sin firmar** en un runner
macOS. Luego lo firmas e instalas tú desde Windows con tu Apple ID gratuito.

**1. Descarga el `.ipa`:**

1. En GitHub: pestaña **Actions** → workflow **Build Jarvis IPA** → último run verde ✅.
2. Abajo, en **Artifacts**, descarga `Jarvis-ipa` y descomprime el zip → obtienes `Jarvis.ipa`.

**2. Instálalo desde tu PC con Windows:**

1. Instala [iTunes](https://www.apple.com/itunes/) (hace falta por los drivers de Apple) y [Sideloadly](https://sideloadly.io).
2. Conecta el iPhone por USB y desbloquéalo (toca "Confiar" si pregunta).
3. Abre Sideloadly: arrastra `Jarvis.ipa`, escribe tu **Apple ID** y pulsa **Start** (la contraseña se envía solo a Apple; si tienes 2FA te pedirá el código).

**3. En el iPhone (solo la primera vez):**

1. Ajustes → General → **VPN y gestión de dispositivos** → toca tu Apple ID → **Confiar**.
2. Ajustes → Privacidad y seguridad → **Modo de desarrollador** → activar (pide reiniciar).

**Limitaciones del Apple ID gratuito:** la app caduca a los **7 días** — se
vuelve a instalar desde Sideloadly en 2 minutos, sin recompilar nada — y solo
puedes tener 3 apps instaladas así a la vez.

## Compilar y ejecutar (con Mac)

El proyecto Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(el `.xcodeproj` no está en el repo):

```bash
brew install xcodegen
cd jarvis
xcodegen generate
open Jarvis.xcodeproj
```

En Xcode:

1. Target **Jarvis** → *Signing & Capabilities* → selecciona tu **Team** personal.
2. Conecta tu iPhone y ejecuta (⌘R).
3. Concede los permisos de **micrófono** y **reconocimiento de voz** al arrancar
   (los de recordatorios y ubicación se piden la primera vez que se usan).
4. Toca el engranaje → pega tu clave de API → **Guardar clave** → **Probar conexión**.
5. Di **«Jarvis»** y luego tu orden. También puedes tocar el reactor para hablar
   directamente, o tocarlo mientras habla para interrumpirle.

### Mejor voz (recomendado)

La voz por defecto de iOS es robótica. Descarga una voz mejorada en
*Ajustes → Accesibilidad → Contenido hablado → Voces → Español* (por ejemplo,
una voz «Premium»): la app elige automáticamente la de mayor calidad instalada.

## Configurar el correo de Outlook (Azure, gratis, ~5 minutos)

Para que Jarvis pueda leer y enviar tu correo necesita una "app" registrada en
Microsoft Azure (es gratis y no requiere suscripción):

1. Entra en [portal.azure.com](https://portal.azure.com) con tu cuenta Microsoft
   (vale la personal de outlook.com/hotmail) → busca **Microsoft Entra ID** →
   **App registrations** → **New registration**.
2. Nombre: `Jarvis`. En *Supported account types* elige
   **"Personal Microsoft accounts only"**.
3. En *Redirect URI* selecciona la plataforma **"Mobile and desktop applications"**
   (si no aparece aquí, añádela después en **Authentication → Add a platform**) y
   escribe como URI personalizada: `jarvis-auth://callback`
4. Pulsa **Register** y copia el **Application (client) ID** (un GUID).
5. En **Authentication**, baja hasta *Advanced settings* y activa
   **"Allow public client flows" = Yes** → Save.
6. En Jarvis: Ajustes ⚙️ → sección **Outlook (Microsoft)** → pega el Application ID
   → **Iniciar sesión con Microsoft** → acepta los permisos (leer y enviar tu correo).

La sesión se guarda cifrada en el llavero del iPhone y se renueva sola; solo
tendrás que volver a iniciarla si pasas ~3 meses sin usarla.

**Notas sobre las demás integraciones:** WhatsApp y Uber se abren mediante
enlaces universales (si la app no está instalada se abre la versión web); la
música requiere suscripción a Apple Music y usa la app Música del sistema.
Los permisos de contactos y biblioteca musical se piden la primera vez que se usan.

## Arquitectura

MVVM sin dependencias externas (solo frameworks de Apple):

```
Jarvis/
├── JarvisApp.swift              # @main
├── Models/                      # estado, mensajes, tipos Codable del Messages API
├── Services/
│   ├── SpeechRecognizer.swift   # AVAudioEngine + SFSpeechRecognizer (wake word + comando)
│   ├── SpeechSynthesizer.swift  # AVSpeechSynthesizer (voz es premium > enhanced)
│   ├── ClaudeClient.swift       # POST /v1/messages + bucle agéntico de herramientas
│   ├── ToolExecutor.swift       # despacho de tool_use → tool_result
│   ├── WeatherService.swift     # CoreLocation + Open-Meteo
│   ├── RemindersService.swift   # EventKit
│   ├── MusicService.swift       # iTunes Search API + MediaPlayer (Apple Music)
│   ├── ContactsService.swift    # búsqueda difusa en la agenda (CNContactStore)
│   ├── DeepLinks.swift          # WhatsApp (wa.me) y Uber (m.uber.com/ul)
│   ├── Microsoft/
│   │   ├── MicrosoftAuthService.swift  # OAuth PKCE sin MSAL (ASWebAuthenticationSession)
│   │   └── OutlookService.swift        # Microsoft Graph: leer y enviar correo
│   ├── KeychainStore.swift      # secretos en el llavero (API key, tokens Microsoft)
│   └── AudioSessionManager.swift
├── ViewModels/
│   └── AssistantViewModel.swift # máquina de estados y orquestación
└── Views/                       # HUD, reactor (Canvas), waveform, historial, ajustes
```

Flujo: `escucha wake word → «Jarvis» → transcribe la orden (fin por 1,5 s de
silencio) → Claude (con herramientas, hasta 5 iteraciones) → respuesta por
voz → vuelve a escuchar`. El reconocimiento se detiene por completo mientras
Jarvis habla para que no se active a sí mismo.

## Notas técnicas

- La clave de API se guarda **solo** en el llavero del dispositivo y viaja
  únicamente a `api.anthropic.com`.
- Modelo por defecto `claude-sonnet-5` (editable en Ajustes). Se envía
  `thinking: disabled` para minimizar la latencia de voz.
- El reconocimiento «es-ES» transcribe «Jarvis» de forma difusa, así que se
  aceptan variantes fonéticas (yarvis, harvis, jarbis…).
- Las tareas de SFSpeechRecognizer caducan (~1 min): en modo wake word la
  tarea se reinicia cada 50 s sin parar el motor de audio.
