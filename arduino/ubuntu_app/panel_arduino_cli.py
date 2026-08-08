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
    -p / --puerto  puerto serie (por defecto se autodetecta ttyUSB*/ttyACM*)
    -b / --baudios velocidad (por defecto 9600)
    -e / --espera  segundos de espera tras abrir el puerto (el Arduino se
                   reinicia al abrirlo; por defecto 2.0)

Requisitos: sudo apt install python3-serial   (o: pip install pyserial)
"""

import argparse
import glob
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
    """Puertos serie candidatos. En WSL2 los USB aparecen como /dev/ttyUSB*
    tras engancharlos con usbipd; en WSL1 los COM de Windows son /dev/ttyS*."""
    puertos = []
    if list_ports is not None:
        puertos = [p.device for p in list_ports.comports()
                   if 'ttyUSB' in p.device or 'ttyACM' in p.device]
    if not puertos:
        puertos = sorted(glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*'))
    return puertos


def elegir_puerto(explicito):
    if explicito:
        return explicito
    puertos = puertos_disponibles()
    if not puertos:
        print('No se ha encontrado ningún puerto serie (ttyUSB*/ttyACM*).')
        print('  - ¿Está el Arduino conectado por USB?')
        print('  - En WSL2 hay que engancharlo antes desde Windows con usbipd')
        print('    (mira arduino/ubuntu_app/README.md).')
        print('  - En WSL1 los COM de Windows son /dev/ttyS<n> (COM3 = ttyS3);')
        print('    en ese caso indícalo con -p /dev/ttyS3.')
        sys.exit(1)
    if len(puertos) > 1:
        print(f'Hay varios puertos: {", ".join(puertos)}. Uso {puertos[0]} '
              '(elige otro con -p).')
    return puertos[0]


def abrir(puerto, baudios, espera):
    if serial is None:
        print('Falta el módulo pyserial. Instálalo con:')
        print('  sudo apt install python3-serial   (o: pip install pyserial)')
        sys.exit(1)
    try:
        con = serial.Serial(puerto, baudios, timeout=0.5)
    except serial.SerialException as e:
        print(f'No se pudo abrir {puerto}: {e}')
        if 'ermission' in str(e):
            print('Permisos: añade tu usuario al grupo dialout y reabre la '
                  'terminal:\n  sudo usermod -a -G dialout $USER')
        sys.exit(1)
    # El Arduino se reinicia al abrir el puerto: darle tiempo a arrancar
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
        cruda = con.readline()
        if not cruda:
            continue
        texto = interpretar(cruda.decode('utf-8', errors='replace').strip())
        if texto:
            print(f'  {texto}')


def enviar(con, comando, escucha=1.0):
    con.write((comando + '\n').encode('ascii'))
    escuchar(con, escucha)


def modo_monitor(con):
    print('Monitor en vivo — Ctrl+C para salir.')
    try:
        while True:
            cruda = con.readline()
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
    parser.add_argument('-e', '--espera', type=float, default=ESPERA_DEFECTO,
                        help='segundos de espera tras abrir el puerto')
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
            print('Ningún puerto ttyUSB*/ttyACM* encontrado.')
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
