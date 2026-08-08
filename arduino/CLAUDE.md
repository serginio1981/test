# CLAUDE.md — reglas del proyecto arduino/

Instrucciones para Claude Code al trabajar en esta carpeta.

## Documentación: siempre al día

**Cada cambio en `arduino/` debe actualizar la documentación en el mismo
commit.** Sin excepciones:

- `arduino/MANUAL.md` — el manual de referencia: cableado, librerías,
  comandos serie, tabla de solución de problemas. Si el cambio añade
  hardware, pines, comandos o un problema nuevo resuelto, va aquí.
- `arduino/README.md` — el índice del proyecto: mapa de carpetas, tabla de
  hardware, resumen de cada sketch y app. Si el cambio añade/renombra un
  sketch, una app o una carpeta, va aquí.
- `arduino/apps/README.md` — si el cambio toca las apps de PC.
- El manual web (artifact de Claude) refleja el MANUAL.md; actualizarlo
  cuando cambie el cableado, los pasos de conexión o las rutas.

## Convenciones ya establecidas

- Estructura: sketches en `arduino/<nombre>/<nombre>.ino`; apps de PC en
  `arduino/apps/` con extras específicos en `apps/windows/` y `apps/linux/`.
- Los sketches con pantalla usan el selector `#define PANTALLA_SH1106`
  (Adafruit SH110X por defecto; SSD1306 si se comenta). La pantalla real de
  este proyecto es SH1106 en 0x3C.
- Protocolo serie a 9600 baudios, líneas parseables `CLAVE:valor`
  (`MODO:`, `ANGULO:`, `SOLAR:`, `EVENTO:ALARMA`) y comandos de un carácter
  (+argumento): `A<n>`, `C`, `M<n>`, `P`, `?`.
- Verificar la compilación con `arduino-cli` (placas `arduino:avr:mega` y
  `arduino:avr:uno`, y ambas variantes de pantalla si el sketch usa OLED)
  antes de subir cambios de sketches.
- Comentarios y textos de usuario en español; el usuario trabaja en Windows
  con WSL2 y SIN permisos de administrador — ninguna solución puede
  requerir admin.
