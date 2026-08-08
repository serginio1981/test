# Panel Arduino — aplicación de escritorio para Ubuntu

Interfaz gráfica (Python + Tkinter) que se conecta por USB a los sketches de
este repo y permite controlarlos desde el PC:

- **Arduino UNO** (`uno_boton_led`): cambia el modo del LED con botones y ve
  el modo actual (también se refleja en la OLED del montaje).
- **Arduino MEGA** (`mega_panel_control`): mueve el servo con un deslizador,
  céntralo con un botón y observa el voltaje de la placa solar en tiempo
  real con una barra.
- **Monitor serie** integrado para ver todo lo que envía y recibe.

La app detecta sola qué datos llegan, así que sirve igual con el UNO que con
el MEGA conectado.

## Instalación en Ubuntu

```bash
sudo apt update
sudo apt install python3-tk python3-serial
```

Para poder abrir el puerto USB sin ser root (solo la primera vez):

```bash
sudo usermod -a -G dialout $USER
```

Después cierra sesión y vuelve a entrar.

## Uso

1. Conecta el Arduino por USB (con el sketch correspondiente ya subido).
2. Ejecuta:

   ```bash
   python3 panel_arduino.py
   ```

3. Pulsa **Buscar**, elige el puerto (normalmente `/dev/ttyUSB0` para
   placas clónicas con chip CH340, o `/dev/ttyACM0` para UNO oficiales)
   y pulsa **Conectar**.

Al conectar, el Arduino se reinicia (es normal); la app pide el estado
automáticamente a los 2 segundos.

## Acceso directo en el escritorio (opcional)

Edita `panel-arduino.desktop`, cambia la línea `Exec=` poniendo la ruta real
del script en tu equipo y cópialo a:

```bash
cp panel-arduino.desktop ~/.local/share/applications/
```

Aparecerá como «Panel Arduino» en el lanzador de aplicaciones.

## Protocolo serie (por si quieres ampliarlo)

| Dirección | Mensaje | Significado |
|-----------|---------|-------------|
| PC → UNO | `M0`..`M3` | Fijar modo del LED |
| PC → MEGA | `A<n>` | Mover servo a `n` grados (0–180) |
| PC → MEGA | `C` | Centrar servo (90°) |
| PC → ambos | `?` | Pedir el estado actual |
| UNO → PC | `MODO:n` | Modo actual del LED |
| MEGA → PC | `ANGULO:n` | Ángulo actual del servo |
| MEGA → PC | `SOLAR:v` | Voltaje de la placa solar |

Todo a **9600 baudios**.
