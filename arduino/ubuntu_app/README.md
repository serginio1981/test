# Panel Arduino — aplicaciones para Ubuntu

Dos formas de controlar los Arduinos desde el PC:

- **`panel_arduino.py`** — interfaz gráfica (Tkinter). Necesita escritorio.
- **`panel_arduino_cli.py`** — versión de terminal, sin entorno gráfico.
  Ideal para **WSL** o servidores.

## Aplicación gráfica (`panel_arduino.py`)

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

## Versión de terminal (`panel_arduino_cli.py`)

Funciona en cualquier Ubuntu sin escritorio (WSL, servidores, SSH). Solo
necesita pyserial:

```bash
sudo apt install python3-serial
```

### Órdenes sueltas

```bash
python3 panel_arduino_cli.py puertos     # lista los puertos serie
python3 panel_arduino_cli.py estado      # muestra el estado actual
python3 panel_arduino_cli.py led 2       # LED del UNO en parpadeo lento
python3 panel_arduino_cli.py servo 135   # servo del MEGA a 135 grados
python3 panel_arduino_cli.py centrar     # servo a 90 grados
python3 panel_arduino_cli.py monitor     # datos en vivo (Ctrl+C para salir)
```

### Modo interactivo

Ejecuta sin argumentos y escribe comandos (`ayuda` los lista):

```bash
python3 panel_arduino_cli.py
> led 3
> servo 45
> monitor
> salir
```

El puerto se autodetecta; si hay varios, o usas WSL1, indícalo con
`-p /dev/ttyS3`, por ejemplo. El programa espera 2 s tras abrir el puerto
porque el Arduino se reinicia al conectar (ajustable con `-e`).

## Usar el Arduino desde WSL (Windows)

WSL no ve los USB de Windows directamente; depende de la versión:

### WSL2 (lo habitual hoy)

Hay que "enganchar" el USB del Arduino a WSL con
[usbipd-win](https://github.com/dorssel/usbipd-win). En **PowerShell de
Windows como administrador**:

```powershell
winget install usbipd            # solo la primera vez
usbipd list                      # busca el Arduino (CH340 / USB Serial)
usbipd bind --busid <BUSID>      # solo la primera vez por dispositivo
usbipd attach --wsl --busid <BUSID>
```

A partir de ahí el Arduino aparece en Ubuntu/WSL como `/dev/ttyUSB0`
(clones CH340) o `/dev/ttyACM0` (UNO oficial). Si da error de permisos:

```bash
sudo usermod -a -G dialout $USER   # y reabre la terminal de WSL
```

El `attach` hay que repetirlo cada vez que desconectes el USB o reinicies
(o usa `usbipd attach --wsl --busid <BUSID> --auto-attach`). Mientras está
enganchado a WSL, Windows no lo ve — para subir sketches con el IDE de
Arduino en Windows, primero `usbipd detach --busid <BUSID>`.

### WSL1

Los puertos COM de Windows se ven directamente como `/dev/ttyS<n>`
(COM3 → `/dev/ttyS3`). Usa `-p /dev/ttyS3` al lanzar la CLI.

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
