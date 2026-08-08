# Proyectos Arduino

Dos programas pensados para el material de las fotos: Arduino UNO, Arduino
MEGA 2560, protoboard con pulsador y LED, pantalla OLED SSD1306, servo SG90,
encoder rotativo y una placa solar pequeña.

## 1. `uno_boton_led/` — Arduino UNO

Usa el montaje que ya tienes en la protoboard (pulsador + LED). Cada
pulsación cambia el modo del LED: apagado → encendido → parpadeo lento →
parpadeo rápido. Incluye antirrebote por software y mensajes por el monitor
serie (9600 baudios).

| Componente | Pin UNO |
|------------|---------|
| LED (con resistencia 220 Ω) | 9 |
| Pulsador (al GND, pull-up interna) | 2 |

No necesita ninguna librería. Abre el `.ino` en el IDE de Arduino,
selecciona **Arduino UNO** como placa y sube.

## 2. `mega_panel_control/` — Arduino MEGA 2560

Mini estación de control que junta el resto de componentes:

- Girando el **encoder** mueves el **servo SG90** de 0° a 180°.
- Pulsando el eje del encoder el servo vuelve al centro (90°).
- La **OLED** muestra el ángulo del servo y el voltaje de la **placa solar**
  (leída por A0), con una barra gráfica del ángulo.

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
