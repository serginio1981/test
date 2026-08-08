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

## App portable para Windows (`PanelArduino.exe`)

La interfaz gráfica también existe como **ejecutable portable de Windows**:
un único `PanelArduino.exe` que no necesita Python, ni instalación, ni
permisos de administrador — cópialo a cualquier carpeta (o un USB) y doble
clic. Se conecta directo al COM del Arduino e incluye los controles del
sketch multiusos (modos Alarma/Nivel/Theremin, botón Pulsar) y hace sonar
la alarma en Windows cuando el MEGA la dispara.

Dos maneras de conseguir el .exe:

1. **Descargarlo de GitHub Actions** (recomendado): pestaña **Actions** del
   repo → workflow *Build PanelArduino.exe* → última ejecución → sección
   **Artifacts** → `PanelArduino-windows-portable`. (Si no hay ninguna
   ejecución, lánzala con *Run workflow*.)
2. **Construirlo tú mismo** (sin admin, ~2 min): doble clic a
   [`construir_exe.bat`](construir_exe.bat) en esta carpeta. Deja el
   resultado en `dist\PanelArduino.exe`.

> ⚠️ Cierra el puente TCP y el IDE antes de conectar el .exe al COM — solo
> un programa puede usar el puerto a la vez. Y al ser un .exe sin firmar,
> Windows SmartScreen puede avisar la primera vez: «Más información →
> Ejecutar de todas formas» (no pide admin).

## Medidor analógico de CPU (`medidor_cpu.py`)

Convierte el servo en un vúmetro físico del PC: 0% de CPU = 0°, 100% = 180°.
Pega una flecha de cartón al eje y tendrás un medidor de aguja de escritorio.

```powershell
# En Windows (mide la CPU real del PC; cierra antes el puente):
python medidor_cpu.py -p COM4
```

También corre en WSL/Linux (midiendo la CPU de esa máquina) con los mismos
puertos que la CLI, incluido `escuchar://`. Opciones: `-i` intervalo,
`-s` suavizado de la aguja, `-n` número de medidas. Al salir con Ctrl+C
centra el servo.

## Usar el Arduino desde WSL (Windows)

WSL no ve los USB de Windows directamente. Comprueba primero tu versión
con `wsl -l -v` en PowerShell; el camino depende de ella y de si tienes
permisos de administrador en Windows.

### WSL2 sin permisos de administrador (puente TCP)

usbipd-win **requiere administrador** (instala un servicio y un driver) y
no tiene versión portable. La alternativa: `puente_com_tcp.py`, un script
que corre en Windows con un Python normal, abre el COM del Arduino y lo
sirve por TCP para que la CLI de WSL se conecte por red.

1. En Windows, instala Python desde la **Microsoft Store** (no pide admin)
   y luego, en PowerShell:

   ```powershell
   pip install --user pyserial
   python -m serial.tools.list_ports -v   # localiza el COM del Arduino
   python puente_com_tcp.py COM3
   ```

   El COM también se ve en el Administrador de dispositivos (`Win+R` →
   `devmgmt.msc`, se abre sin admin) en **"Puertos (COM y LPT)"** — el MEGA
   clon aparece como *USB-SERIAL CH340*. Si Windows muestra un aviso del
   firewall al arrancar el puente y no puedes aceptarlo (pide admin),
   ciérralo y usa el modo *mirrored* de más abajo.

2. En WSL/Ubuntu, averigua la IP de Windows y conéctate:

   ```bash
   ip route show default | awk '{print $3}'      # IP de Windows vista desde WSL2
   python3 panel_arduino_cli.py -p socket://<esa-IP>:8765 estado
   ```

> La velocidad (baudios) la fija el **puente** con su opción `-b`; el `-b`
> de la CLI no viaja por `socket://`.

### Si `socket://` da "timed out": modo inverso (`-c` / `escuchar://`)

Ese timeout es el **firewall de Windows** bloqueando la entrada desde WSL,
y sin admin no puedes abrirle el puerto. El rodeo más fiable es **invertir
el sentido de la conexión**: WSL→Windows está bloqueado, pero
Windows→WSL pasa siempre. La CLI se pone a escuchar y el puente se conecta
a ella. Funciona en cualquier Windows (10 u 11), sin tocar nada.

1. En **WSL/Ubuntu** (primero):

   ```bash
   python3 panel_arduino_cli.py -p escuchar://:8765
   ```

   Al arrancar imprime el comando exacto que hay que lanzar en Windows,
   con tu IP de WSL ya puesta.

2. En **Windows** (después):

   ```powershell
   python puente_com_tcp.py COM4 -c <IP-de-WSL>:8765
   ```

   Si el puente arranca antes que la CLI no pasa nada: reintenta cada 2 s
   hasta que la CLI aparezca.

> La IP de WSL cambia en cada reinicio de WSL (también la ves con
> `hostname -I`). Si un día no conecta, vuelve a mirar la IP.

### Alternativa: modo mirrored (solo Windows 11)

Otro rodeo sin admin es el modo **mirrored** de WSL, en el que Windows y
WSL comparten localhost y el firewall no interviene.
Requiere **Windows 11 22H2+ y WSL 2.0+**; actualiza y comprueba primero
(ninguno de los dos pide admin):

```powershell
wsl --update
wsl --version     # WSL debe ser 2.0.0 o superior
```

Después crea el archivo `%UserProfile%\.wslconfig` con:

```ini
[wsl2]
networkingMode=mirrored
```

Ejecuta `wsl --shutdown`, vuelve a abrir Ubuntu, lanza el puente con
`python puente_com_tcp.py COM3 -d 127.0.0.1` y conecta desde WSL a
`socket://127.0.0.1:8765`.

> Si al arrancar WSL avisa de que *mirrored no está soportado y vuelve a
> NAT*, tu Windows no lo admite: en ese caso `socket://127.0.0.1` dará
> «connection refused» — vuelve a lanzar el puente sin `-d` y usa la IP de
> Windows, o pasa al Plan B.

**Plan B sin WSL:** la CLI también funciona directamente en Windows con el
Python de la Store (`pip install --user pyserial` y
`python panel_arduino_cli.py -p COM3`), sin puente ni WSL.

### WSL2 con permisos de administrador (usbipd)

Es la vía "oficial": engancha el USB del Arduino a WSL con
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
