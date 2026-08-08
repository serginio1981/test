#!/usr/bin/env python3
"""Panel Arduino CLI — control por terminal, pensado para WSL/Ubuntu sin escritorio.

Habla con los sketches de este repo por el puerto serie:
  - Arduino UNO  (uno_boton_led):    modos del LED (M0..M3)
  - Arduino MEGA (mega_panel_control): servo (A<ángulo>, C) y placa solar

Uso — órdenes sueltas:
    python3 panel_arduino_cli.py puertos            # lista puertos serie
    python3 panel_arduino_cli.py estado             # pide y muestra el estado
    python3 panel_arduino_cli.py led 2              # modo del LED (0..3)
    python3 panel_arduino_cli.py servo 135          # mueve el servo (0..180)
    python3 panel_arduino_cli.py centrar            # servo a 90 grados
    python3 panel_arduino_cli.py monitor            # muestra datos en vivo (Ctrl+C)

Uso — modo interactivo (sin argumentos):
    python3 panel_arduino_cli.py
    > led 3
    > servo 45
    > monitor
    > salir

Opciones:
    -p / --puerto  puerto serie; por defecto se autodetecta. Acepta:
                     /dev/ttyUSB0            (Linux / WSL2 con usbipd)
                     /dev/ttyS3              (WSL1: COM3 de Windows)
                     COM3                    (Windows nativo)
                     socket://<ip>:8765      (puente puente_com_tcp.py)
                     escuchar://:8765        (modo inverso: la CLI espera y
                                              el puente se conecta; usar si
                                              el firewall de Windows corta
                                              socket:// con "timed out")
    -b / --baudios velocidad (por defecto 9600; con socket:// la fija el
                   puente, no esta opción)
    -e / --espera  segundos de espera tras abrir el puerto (por defecto 2.0
                   en serie directa, porque el Arduino se reinicia al
                   abrirla; 0.5 con socket://, donde no se reinicia)

Requisitos: sudo apt install python3-serial   (o: pip install pyserial)
"""

import argparse
import glob
import socket
import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    serial = None
    list_ports = None

BAUDIOS_DEFECTO = 9600
ESPERA_DEFECTO = 2.0
NOMBRES_MODO = ['Apagado', 'Encendido', 'Parpadeo lento', 'Parpadeo rápido']

AYUDA_INTERACTIVO = """Comandos disponibles:
  led <0-3>      modo del LED del UNO (0 apagado, 1 fijo, 2 lento, 3 rápido)
  servo <0-180>  mueve el servo del MEGA a ese ángulo
  centrar        servo a 90 grados
  estado         pide el estado actual
  monitor        muestra los datos en vivo (Ctrl+C para volver)
  crudo <texto>  envía el texto tal cual por el puerto serie
  ayuda          muestra esta ayuda
  salir          termina el programa"""


def puertos_disponibles():
    """Puertos serie candidatos.

    - Linux normal / WSL2 con usbipd: /dev/ttyUSB* o /dev/ttyACM*
    - WSL1: los COM de Windows son /dev/ttyS* (indícalo con -p)
    - Windows nativo: COM3, COM4, ... (este script también funciona ahí)
    """
    puertos = []
    if list_ports is not None:
        if sys.platform.startswith('win'):
            # Prioriza dispositivos USB reales (el Arduino tiene VID);
            # los COM de Bluetooth no lo tienen y abrirse pueden tardar
            # 10 s en fallar.
            todos = list(list_ports.comports())
            usb = [p.device for p in todos if p.vid is not None]
            puertos = usb or [p.device for p in todos]
        else:
            puertos = [p.device for p in list_ports.comports()
                       if 'ttyUSB' in p.device or 'ttyACM' in p.device]
    if not puertos and not sys.platform.startswith('win'):
        puertos = sorted(glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*'))
    # Orden natural: COM2 antes que COM10
    return sorted(puertos, key=lambda d: (len(d), d))


def elegir_puerto(explicito):
    if explicito:
        return explicito
    puertos = puertos_disponibles()
    if not puertos:
        print('No se ha encontrado ningún puerto serie.')
        print('  - ¿Está el Arduino conectado por USB?')
        print('  - En WSL2 hay que engancharlo desde Windows con usbipd, o')
        print('    usar el puente TCP sin admin: ejecuta puente_com_tcp.py en')
        print('    Windows y conecta con -p socket://<ip>:8765')
        print('    (mira arduino/ubuntu_app/README.md).')
        print('  - En WSL1 los COM de Windows son /dev/ttyS<n> (COM3 = ttyS3);')
        print('    en ese caso indícalo con -p /dev/ttyS3.')
        sys.exit(1)
    if len(puertos) > 1:
        print(f'Hay varios puertos: {", ".join(puertos)}. Uso {puertos[0]} '
              '(elige otro con -p).')
    return puertos[0]


def _ip_local():
    """IP de esta máquina (la de WSL vista desde Windows)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))   # no envía nada; solo elige ruta
        return s.getsockname()[0]
    except OSError:
        return '<IP-de-WSL: hostname -I>'
    finally:
        s.close()


class ConexionEscucha:
    """Modo inverso: la CLI escucha y el puente de Windows se conecta aquí.

    El firewall de Windows suele bloquear WSL->Windows, pero Windows->WSL
    pasa siempre. Imita la parte de serial.Serial que usa este script
    (readline / write / reset_input_buffer / close).
    """

    def __init__(self, direccion, puerto):
        servidor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            servidor.bind((direccion, puerto))
        except OSError as e:
            print(f'No se pudo escuchar en el puerto {puerto}: {e}')
            sys.exit(1)
        servidor.listen(1)
        print(f'Esperando al puente... Lanza en Windows (PowerShell):')
        print(f'  python puente_com_tcp.py COM4 -c {_ip_local()}:{puerto}')
        print('(Ctrl+C para cancelar)')
        try:
            self._sock, origen = servidor.accept()
        except KeyboardInterrupt:
            print('\nCancelado.')
            servidor.close()
            sys.exit(1)
        servidor.close()
        print(f'Puente conectado desde {origen[0]}')
        self._sock.settimeout(0.5)
        self._buf = b''

    def readline(self):
        while b'\n' not in self._buf:
            try:
                datos = self._sock.recv(1024)
            except socket.timeout:
                return b''                    # como serial.Serial con timeout
            except OSError as e:
                raise serial.SerialException(
                    f'se perdió la conexión con el puente: {e}')
            if not datos:
                raise serial.SerialException('el puente cerró la conexión')
            self._buf += datos
        linea, self._buf = self._buf.split(b'\n', 1)
        return linea + b'\n'

    def write(self, datos):
        try:
            self._sock.sendall(datos)
        except OSError as e:
            raise serial.SerialException(
                f'se perdió la conexión con el puente: {e}')
        return len(datos)

    def reset_input_buffer(self):
        self._buf = b''
        self._sock.setblocking(False)
        try:
            while self._sock.recv(4096):
                pass
        except (BlockingIOError, OSError):
            pass
        finally:
            self._sock.settimeout(0.5)

    def close(self):
        try:
            self._sock.close()
        except OSError:
            pass


def abrir(puerto, baudios, espera):
    if serial is None:
        print('Falta el módulo pyserial. Instálalo con:')
        print('  sudo apt install python3-serial   (o: pip install pyserial)')
        sys.exit(1)
    es_url = '://' in puerto
    try:
        if puerto.startswith('escuchar://'):
            # Modo inverso: nosotros escuchamos y el puente se conecta.
            resto = puerto[len('escuchar://'):]
            host, _, p = resto.rpartition(':')
            con = ConexionEscucha(host or '0.0.0.0',
                                  int(p) if p.isdigit() else 8765)
        elif es_url:
            # URL de pyserial, p. ej. socket://192.168.1.10:8765
            # (para el puente COM<->TCP de puente_com_tcp.py desde WSL)
            con = serial.serial_for_url(puerto, timeout=0.5)
        else:
            con = serial.Serial(puerto, baudios, timeout=0.5)
    except (serial.SerialException, OSError, ValueError) as e:
        print(f'No se pudo abrir {puerto}: {e}')
        if 'ermission' in str(e):
            print('Permisos: añade tu usuario al grupo dialout y reabre la '
                  'terminal:\n  sudo usermod -a -G dialout $USER')
        if es_url:
            print('¿Está corriendo puente_com_tcp.py en Windows y es '
                  'correcta la IP? (mira el README, sección WSL sin admin)')
        sys.exit(1)
    if es_url and baudios != BAUDIOS_DEFECTO:
        print(f'Aviso: -b {baudios} no viaja por socket://; la velocidad '
              'la fija el puente (su opción -b).')
    if espera is None:
        # Sobre el puente TCP el Arduino NO se reinicia al conectar (solo
        # cuando el puente abre el COM), asi que no hay que esperar arranque.
        espera = 0.5 if es_url else ESPERA_DEFECTO
    time.sleep(espera)
    con.reset_input_buffer()
    return con


def interpretar(linea):
    """Convierte una línea del protocolo en texto legible (o None)."""
    if linea.startswith('MODO:'):
        try:
            n = int(linea.split(':', 1)[1])
            return f'LED -> modo {n} ({NOMBRES_MODO[n]})'
        except (ValueError, IndexError):
            return linea
    if linea.startswith('ANGULO:'):
        return f'Servo -> {linea.split(":", 1)[1]} grados'
    if linea.startswith('SOLAR:'):
        return f'Placa solar -> {linea.split(":", 1)[1]} V'
    return linea if linea else None


def escuchar(con, segundos):
    """Lee e imprime respuestas durante un tiempo dado."""
    limite = time.monotonic() + segundos
    while time.monotonic() < limite:
        try:
            cruda = con.readline()
        except (serial.SerialException, OSError):
            print('  (se perdió la conexión con el Arduino/puente)')
            return
        if not cruda:
            continue
        texto = interpretar(cruda.decode('utf-8', errors='replace').strip())
        if texto:
            print(f'  {texto}')


def enviar(con, comando, escucha=1.0):
    try:
        con.write((comando + '\n').encode('ascii'))
    except (serial.SerialException, OSError):
        print('  No se pudo enviar (¿se perdió la conexión?)')
        return
    escuchar(con, escucha)


def modo_monitor(con):
    print('Monitor en vivo — Ctrl+C para salir.')
    try:
        while True:
            try:
                cruda = con.readline()
            except (serial.SerialException, OSError):
                print('Se perdió la conexión con el Arduino/puente.')
                return
            if not cruda:
                continue
            texto = interpretar(cruda.decode('utf-8', errors='replace').strip())
            if texto:
                print(texto)
    except KeyboardInterrupt:
        print()


def ejecutar_comando(con, orden, argumento):
    if orden == 'led':
        if argumento is None or argumento not in ('0', '1', '2', '3'):
            print('Uso: led <0-3>')
            return
        enviar(con, f'M{argumento}')
    elif orden == 'servo':
        try:
            angulo = int(argumento)
        except (TypeError, ValueError):
            print('Uso: servo <0-180>')
            return
        angulo = max(0, min(180, angulo))
        enviar(con, f'A{angulo}')
    elif orden == 'centrar':
        enviar(con, 'C')
    elif orden == 'estado':
        enviar(con, '?', escucha=1.5)
    elif orden == 'monitor':
        modo_monitor(con)
    elif orden == 'crudo':
        if not argumento:
            print('Uso: crudo <texto>')
            return
        enviar(con, argumento)
    else:
        print(f'Orden desconocida: {orden} (escribe "ayuda")')


def modo_interactivo(con, puerto):
    print(f'Conectado a {puerto}. Escribe "ayuda" para ver los comandos.')
    while True:
        try:
            entrada = input('> ').strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not entrada:
            continue
        partes = entrada.split(None, 1)
        orden = partes[0].lower()
        argumento = partes[1] if len(partes) > 1 else None
        if orden in ('salir', 'exit', 'quit'):
            break
        if orden in ('ayuda', 'help'):
            print(AYUDA_INTERACTIVO)
            continue
        ejecutar_comando(con, orden, argumento)


def main():
    parser = argparse.ArgumentParser(
        description='Control por terminal de los Arduinos (UNO y MEGA) '
                    'de este repo.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='Sin orden entra en modo interactivo.')
    parser.add_argument('-p', '--puerto', help='puerto serie (autodetectado '
                        'si se omite)')
    parser.add_argument('-b', '--baudios', type=int, default=BAUDIOS_DEFECTO)
    parser.add_argument('-e', '--espera', type=float, default=None,
                        help='segundos de espera tras abrir el puerto '
                             '(por defecto 2.0 en serie directa, 0.5 con '
                             'socket:// porque el Arduino no se reinicia)')
    parser.add_argument('orden', nargs='?',
                        choices=['puertos', 'estado', 'led', 'servo',
                                 'centrar', 'monitor', 'crudo'],
                        help='orden a ejecutar (omitir = interactivo)')
    parser.add_argument('argumento', nargs='?',
                        help='argumento de la orden (p. ej. el ángulo)')
    args = parser.parse_args()

    if args.orden == 'puertos':
        puertos = puertos_disponibles()
        if puertos:
            for p in puertos:
                print(p)
        else:
            print('Ningún puerto serie encontrado.')
        return

    puerto = elegir_puerto(args.puerto)
    con = abrir(puerto, args.baudios, args.espera)
    try:
        if args.orden is None:
            modo_interactivo(con, puerto)
        else:
            ejecutar_comando(con, args.orden, args.argumento)
    finally:
        con.close()


if __name__ == '__main__':
    main()
