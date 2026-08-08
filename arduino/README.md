# Estación Arduino — MEGA 2560 + UNO controlados desde Ubuntu (WSL)

Proyecto completo de electrónica y software: dos Arduinos con pantalla OLED,
sensores y actuadores, controlados desde Ubuntu bajo WSL2 en Windows **sin
permisos de administrador**, con apps de escritorio y de terminal.

> 📖 **Manual completo de montaje, conexión y problemas resueltos:
> [MANUAL.md](MANUAL.md)** (con diagramas que GitHub renderiza solos).

## Mapa del proyecto

```
arduino/
├── MANUAL.md                ← empieza por aquí
├── MANUAL_MEGA2560.md       Manual de la placa: specs, pines, ampliaciones
├── mega_panel_control/      Sketch principal del MEGA 2560
├── mpu_multiusos/           Sketch 3-en-1: alarma, nivel y theremin (MEGA)
├── uno_boton_led/           Sketch del UNO: pulsador + LED + OLED
├── escaner_i2c/             Diagnóstico: ¿qué hay en el bus I2C?
├── prueba_mpu6050/          Diagnóstico: ¿el acelerómetro mide bien?
└── apps/                    Apps del PC (GUI, CLI, puente TCP, medidor CPU)
    ├── windows/             construir_exe.bat (build del .exe portable)
    └── linux/               lanzador .desktop
```

## Hardware

| Componente | Papel | Sketch que lo usa |
|---|---|---|
| Arduino MEGA 2560 (clon CH340) | Cerebro principal | `mega_panel_control`, `mpu_multiusos` |
| Arduino UNO | Segundo cerebro | `uno_boton_led` |
| OLED 128×64 I²C (chip SH1106) | Pantalla de la estación | todos los principales |
| Encoder rotativo EC11 | Mando: girar y pulsar | `mega_panel_control`, `mpu_multiusos` |
| Servo SG90 | Movimiento / aguja de medidor | `mega_panel_control` |
| Placa solar ≤5 V | Sensor de luz/voltaje | `mega_panel_control` |
| MPU-6050 | Acelerómetro + giroscopio | `mpu_multiusos`, `prueba_mpu6050` |
| Buzzer pasivo | Sonidos y sirena (opcional) | `mpu_multiusos` |
| LED + resistencia 220 Ω | Sirena visual / indicador | `uno_boton_led`, `mpu_multiusos` |

Cableado completo pin a pin: en [MANUAL.md](MANUAL.md#2-cableado-del-mega).
Capacidades de la placa (¿tiene WiFi?, pines libres, cómo ampliarla):
[MANUAL_MEGA2560.md](MANUAL_MEGA2560.md).

## Sketches

### `mega_panel_control/` — la estación del MEGA

- El **encoder** mueve el **servo** (0–180°); su botón lo centra.
- La **OLED** muestra el ángulo, el voltaje de la **placa solar** y una
  **gráfica** con el histórico de voltaje de los últimos 2 minutos.
- Comandos serie: `A<ángulo>`, `C` (centrar), `?` (estado). Publica
  `ANGULO:n` y `SOLAR:v`.

### `mpu_multiusos/` — 3 proyectos en 1 (MEGA)

Girar el encoder cambia de modo; pulsarlo ejecuta la acción del modo.
También se maneja **sin encoder**, por comandos serie desde la CLI.

| Modo | Qué hace | Botón / `pulsar` |
|---|---|---|
| 🚨 Alarma | Vigila el movimiento con el MPU-6050; sirena (buzzer y/o LED) al detectarlo, y **hace sonar el PC** vía la CLI (`EVENTO:ALARMA`) | Arma / desarma |
| 🫧 Nivel | Burbuja en la OLED según la inclinación; LED fijo al estar nivelado | Calibra el cero |
| 🎵 Theremin | El tono sigue la inclinación (200–1800 Hz); el brillo del LED también | Silencia |

Comandos serie: `M0`/`M1`/`M2` (modo), `P` (como pulsar el botón), `?`.

### `uno_boton_led/` — el UNO

Pulsador que rota 4 modos de LED (apagado/fijo/lento/rápido) con la OLED
mostrando el modo. Comandos serie: `M0`..`M3`, `?`. Publica `MODO:n`.

### Diagnóstico: `escaner_i2c/` y `prueba_mpu6050/`

- **escaner_i2c**: lista qué responde en el bus I²C. La OLED debe salir en
  `0x3C` y el MPU-6050 en `0x68`. Primera herramienta ante cualquier duda.
- **prueba_mpu6050**: imprime la aceleración X/Y/Z en vivo. En plano debe
  marcar `Z: 1.00`; al inclinarlo, la gravedad se muda de eje.

> Todos los sketches con pantalla llevan el selector `#define
> PANTALLA_SH1106`: activo usa la librería **Adafruit SH110X** (nuestra
> pantalla); comentado, **Adafruit SSD1306** (las de 0.96"). Además de la
> **Adafruit GFX** en ambos casos. Si la OLED muestra «nieve», es que el
> selector no coincide con tu chip — historia completa en el manual.

## Apps del PC (`apps/`)

| App | Qué es |
|---|---|
| `panel_arduino_cli.py` | **CLI para WSL/terminal**: `servo 90`, `led 2`, `modo 0`, `pulsar`, `monitor`... y suena la alarma en el PC cuando el MEGA la dispara |
| `puente_com_tcp.py` | **Puente COM↔TCP** que corre en Windows sin admin; su modo inverso (`-c`) esquiva el firewall |
| `panel_arduino.py` | GUI de escritorio (Tkinter) con botones y deslizadores |
| `medidor_cpu.py` | La CPU del PC en el servo: un medidor de aguja físico |

Instrucciones detalladas y el flujo WSL completo: [`apps/README.md`](apps/README.md).

## Conexión desde WSL en 30 segundos (sin admin)

```bash
# Ubuntu/WSL (primero):
python3 apps/panel_arduino_cli.py -p escuchar://:8765
```
```powershell
# Windows (después; con mirrored es 127.0.0.1, si no la CLI te imprime la IP):
python apps\puente_com_tcp.py COM4 -c 127.0.0.1:8765
```

¿Por qué este baile? El firewall de Windows corta WSL→Windows y sin admin no
se puede abrir; Windows→WSL siempre pasa, así que el puente llama a la CLI.
Diagrama y alternativas en el [manual](MANUAL.md#4-la-cadena-de-conexión).

## Cómo subir un programa

1. IDE de Arduino en Windows (hay .zip portable, sin admin).
2. Librerías: **Adafruit SH110X** + **Adafruit GFX** (gestor de librerías o ZIP).
3. Placa **Arduino Mega or Mega 2560** (o **Arduino Uno**) y puerto **COM4**
   (el *USB-SERIAL CH340*; el «Intel AMT-SOL» no es).
4. ⚠️ Cierra el puente TCP antes de subir — solo uno puede usar el COM.
5. Monitor Serie a **9600 baudios** para ver qué cuenta la placa.

## Historial del proyecto

Construido y depurado en vivo: incluye las batallas reales contra el firewall
de Windows, la pantalla SH1106 que fingía ser SSD1306, el puerto COM3
impostor de Intel y un buzzer que llegó muerto. Cada una está documentada en
la [tabla de problemas del manual](MANUAL.md#8-solución-de-problemas) para
que la próxima vez sean 30 segundos y no una tarde.
