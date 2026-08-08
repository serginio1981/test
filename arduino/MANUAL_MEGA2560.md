# Manual de la placa — Arduino MEGA 2560 (clon CH340)

Qué es capaz de hacer tu placa, qué no trae de fábrica, y cómo ampliarla.
(Manual de la estación completa: [MANUAL.md](MANUAL.md).)

## Lo primero: ¿tiene WiFi o Bluetooth?

**No.** El MEGA 2560 no trae ninguna radio: ni WiFi, ni Bluetooth, ni nada
inalámbrico. Es un microcontrolador "clásico": todo entra y sale por cables
(USB o sus pines). La buena noticia: se le puede añadir cualquiera de las
dos con módulos de pocos euros — ver [Cómo ampliarla](#cómo-ampliarla) abajo.

Su **superpoder real es la cantidad**: es la placa Arduino clásica con más
pines, más memoria y más puertos serie. Se eligió para esta estación
precisamente por eso — caben la OLED, el encoder, el servo, la placa solar,
el MPU-6050 y el buzzer a la vez, y sobra la mitad de la placa.

## Ficha técnica

| Característica | MEGA 2560 | (UNO, para comparar) |
|---|---|---|
| Microcontrolador | ATmega2560 @ 16 MHz | ATmega328P @ 16 MHz |
| Lógica | 5 V | 5 V |
| Memoria de programa (flash) | **256 KB** | 32 KB |
| RAM | **8 KB** | 2 KB |
| **EEPROM** (memoria que sobrevive al apagado) | **4 KB** | 1 KB |
| Pines digitales | **54** (15 con PWM) | 14 (6 PWM) |
| Entradas analógicas | **16** (A0–A15, 10 bits) | 6 |
| Puertos serie por hardware | **4** (Serial, Serial1, Serial2, Serial3) | 1 |
| Interrupciones externas | 6 pines (2, 3, 18, 19, 20, 21) | 2 |
| Buses | I²C (20/21) · SPI (50–53) | I²C (A4/A5) · SPI (10–13) |
| Corriente por pin | 20 mA recomendado (40 máx) | igual |
| Alimentación | USB 5 V · jack 7–12 V · VIN | igual |
| Salidas de tensión | 5 V y 3.3 V (máx 50 mA la de 3.3) | igual |
| USB (en el clon) | Chip **CH340** (necesita su driver) | CH340 o ATmega16U2 |

## Qué tiene de especial (y cómo sacarle partido)

### 1. Cuatro puertos serie de verdad

El UNO tiene un único puerto serie que comparte con el USB — por eso
conectar un módulo serie ahí interfiere con la subida de sketches. El MEGA
tiene **tres puertos extra libres** (pines TX1/RX1=18/19, TX2/RX2=16/17,
TX3/RX3=14/15). Ahí se enchufan sin conflicto: módulo Bluetooth, GPS,
lector de huella, otro Arduino, un ESP8266...

### 2. EEPROM: memoria que no se borra al desenchufar

4 KB donde guardar configuración que sobrevive al apagado, con la librería
`EEPROM.h` incluida en el IDE. Idea directa para la estación: guardar la
calibración del cero del nivel o el umbral de la alarma, y que no se
pierdan al desconectar el USB.

### 3. Interrupciones y PWM a espuertas

6 pines de interrupción (nuestro encoder usa el 2) y 15 salidas PWM.
Puedes colgar varios encoders, sensores de pulsos o servos sin pelearte
por los pines, algo que en el UNO se agota enseguida.

### 4. 16 entradas analógicas

Nuestra placa solar usa A0… quedan A1–A15. Dieciséis sensores analógicos
simultáneos: potenciómetros, LDR, sensores de humedad de suelo, etc.

## Qué NO trae (y sus sustitutos baratos)

| No tiene | Se añade con | Precio aprox. |
|---|---|---|
| Bluetooth | Módulo **HC-05** o **HC-06** (serie ↔ BT clásico) en Serial1 | 3–5 € |
| WiFi | Módulo **ESP-01 (ESP8266)** por Serial1 con comandos AT | 2–4 € |
| Reloj en tiempo real (se le olvida la hora al apagarse) | Módulo RTC **DS3231** (I²C, conviviría con OLED y MPU) | 2–3 € |
| Salida de audio analógica (DAC) | PWM + filtro, o módulo DFPlayer para MP3 | 3–5 € |
| Almacenamiento grande | Módulo lector microSD (SPI) | 2–3 € |

> 💡 Si algún día quieres WiFi/Bluetooth "de serie", la placa a mirar es la
> **ESP32** (~5–8 €): trae ambos integrados, se programa desde el mismo IDE
> de Arduino, y conviviría bien con este proyecto — aunque su lógica es de
> 3.3 V (ojo al conectar módulos de 5 V).

## Cómo ampliarla: Bluetooth en 4 cables (ejemplo)

Un HC-05 conectado a Serial1 haría la estación **inalámbrica** sin tocar el
resto del montaje:

```
HC-05      MEGA
VCC   →    5V
GND   →    GND
TXD   →    19 (RX1)
RXD   →    18 (TX1) — mejor con divisor de tensión (2 resistencias)
```

Con `Serial1.begin(9600)` en el sketch y un espejo de comandos entre
`Serial` y `Serial1`, el móvil o el PC se conectan por Bluetooth y hablan
el mismo protocolo (`A90`, `M0`, `P`...) que ya usa la CLI. Pídelo cuando
tengas el módulo y lo integramos.

## Pines usados y libres en esta estación

| Recurso | Usado por | Libre |
|---|---|---|
| 2, 3, 4 | Encoder (CLK, DT, SW) | |
| 8 | Buzzer | |
| 9 | Servo / LED sirena | |
| 13 | LED integrado "L" | |
| 20, 21 (I²C) | OLED (0x3C) + MPU-6050 (0x68) | Admite más módulos I²C con otra dirección |
| A0 | Placa solar | |
| Serial (USB) | CLI / puente / IDE | |
| | | **Serial1/2/3 (14–19), SPI (50–53), pines 5–7, 10–12, 22–49, A1–A15…** |

Más de 40 pines siguen libres: la estación puede crecer mucho todavía.

## Detalles prácticos del clon

- El chip USB es un **CH340**, no el original: por eso en Windows aparece
  como *USB-SERIAL CH340 (COM4)*. El driver suele instalarlo Windows
  Update solo.
- El regulador de voltaje de los clones es modesto: alimentando por el
  jack con 12 V se calienta; **7–9 V es más sano** si usas fuente externa.
- El botón rojo es **RESET**: reinicia el sketch, no lo borra.
- Los dos condensadores plateados y el cristal de 16 MHz junto al USB son
  la "metrónomo" de la placa; el chip grande del centro es el ATmega2560.
