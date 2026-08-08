# Proyectos Arduino

Dos programas pensados para el material de las fotos: Arduino UNO, Arduino
MEGA 2560, protoboard con pulsador y LED, pantalla OLED SSD1306, servo SG90,
encoder rotativo y una placa solar pequeña.

## 1. `uno_boton_led/` — Arduino UNO

Usa el montaje de la protoboard (pulsador + LED) más la pantalla OLED. Cada
pulsación cambia el modo del LED: apagado → encendido → parpadeo lento →
parpadeo rápido. La OLED muestra el modo actual en grande con una barra de
progreso. Incluye antirrebote por software y también acepta comandos por el
puerto serie (`M0`..`M3`) desde la app de escritorio.

| Componente | Pin UNO |
|------------|---------|
| LED (con resistencia 220 Ω) | 9 |
| Pulsador (al GND, pull-up interna) | 2 |
| OLED SDA / SCL | A4 / A5 |

Librerías (Gestor de librerías del IDE): **Adafruit SSD1306** y
**Adafruit GFX Library**. Si no conectas la OLED, el programa funciona
igualmente. Abre el `.ino` en el IDE de Arduino, selecciona **Arduino UNO**
como placa y sube.

## 2. `mega_panel_control/` — Arduino MEGA 2560

Mini estación de control que junta el resto de componentes:

- Girando el **encoder** mueves el **servo SG90** de 0° a 180°.
- Pulsando el eje del encoder el servo vuelve al centro (90°).
- La **OLED** muestra el ángulo del servo y el voltaje de la **placa solar**
  (leída por A0), con una barra gráfica del ángulo.
- Acepta comandos por el puerto serie (`A<ángulo>`, `C`) desde la app de
  escritorio.

| Componente | Pin MEGA |
|------------|----------|
| OLED SDA / SCL | 20 / 21 |
| Encoder CLK / DT / SW | 2 / 3 / 4 |
| Servo (señal) | 9 |
| Placa solar (+) | A0 |

Librerías (Gestor de librerías del IDE): **Adafruit SSD1306** y
**Adafruit GFX Library**. La librería `Servo` ya viene con el IDE.

> ⚠️ La placa solar debe conectarse a A0 solo si da menos de 5 V. Si da más,
> usa un divisor de tensión (dos resistencias iguales en serie) y multiplica
> la lectura por 2 en el código.

## 3. `ubuntu_app/` — Aplicaciones para Ubuntu

Dos programas que se conectan al UNO o al MEGA por USB:

- **`panel_arduino.py`** — interfaz gráfica (Tkinter): botones para el modo
  del LED, deslizador para el servo, lectura en vivo de la placa solar y
  monitor serie integrado.
- **`panel_arduino_cli.py`** — versión de terminal para WSL o equipos sin
  escritorio, con órdenes sueltas (`led 2`, `servo 135`, `monitor`) y modo
  interactivo.

Instrucciones completas (incluido cómo pasar el USB a WSL con usbipd) en
[`ubuntu_app/README.md`](ubuntu_app/README.md).

## Cómo subir un programa

1. Instala el [IDE de Arduino](https://www.arduino.cc/en/software).
2. Abre el archivo `.ino` de la carpeta correspondiente.
3. Conecta la placa por USB y selecciona placa y puerto en
   **Herramientas → Placa / Puerto**.
4. Pulsa el botón de subir (flecha →).
5. Abre el **Monitor Serie** a 9600 baudios para ver los mensajes.

> Nota: los MEGA "clónicos" (como el azul de las fotos) suelen usar el chip
> USB CH340. Si el puerto no aparece, instala el driver CH340 para tu
> sistema operativo.
