#!/usr/bin/env python3
"""Puente COM <-> TCP — para usar el Arduino desde WSL2 SIN permisos de admin.

usbipd-win necesita administrador (instala un servicio y un driver). Este
script es la alternativa portable: se ejecuta en WINDOWS con un Python
normal (el de la Microsoft Store vale y no pide admin), abre el puerto COM
del Arduino y lo sirve por TCP. Desde WSL, la CLI se conecta por red:

    En Windows (PowerShell, sin admin):
        pip install --user pyserial
        python puente_com_tcp.py COM3

    En WSL/Ubuntu:
        python3 panel_arduino_cli.py -p socket://<IP-de-Windows>:8765

    La IP de Windows vista desde WSL2 (modo NAT, el habitual):
        ip route show default | awk '{print $3}'

Para saber el número de COM: `python -m serial.tools.list_ports -v` en
PowerShell, o el Administrador de dispositivos (Win+R, devmgmt.msc),
sección "Puertos (COM y LPT)" — el MEGA clon aparece como USB-SERIAL CH340.

La velocidad (baudios) la fija ESTE script con -b; el -b de la CLI no
viaja por la red (pyserial lo ignora en conexiones socket://).

MODO INVERSO (-c): si el firewall de Windows bloquea la conexión desde WSL
(síntoma: "timed out" en la CLI), invierte el sentido — Windows hacia WSL
está permitido siempre. La CLI se pone a escuchar y este puente se conecta
a ella:

    En WSL/Ubuntu (primero):
        hostname -I | awk '{print $1}'          # IP de WSL, p. ej. 172.17.130.5
        python3 panel_arduino_cli.py -p escuchar://:8765

    En Windows (después):
        python puente_com_tcp.py COM4 -c <IP-de-WSL>:8765

Si la conexión falla, el puente reintenta cada 2 s, así que el orden de
arranque no es crítico. Ojo: la IP de WSL cambia en cada reinicio.

Con WSL en modo "mirrored" (Windows 11: añade networkingMode=mirrored a
%UserProfile%\\.wslconfig y ejecuta `wsl --shutdown`), ambos comparten
localhost: lanza el puente con `-d 127.0.0.1` y conecta desde WSL a
socket://127.0.0.1:8765.

El script también funciona en Linux/macOS (útil para compartir un Arduino
por red local). Acepta un solo cliente a la vez; al desconectarse, espera
al siguiente. Ctrl+C para terminar.

Nota: el Arduino se reinicia cuando ESTE script abre el COM, no cada vez
que un cliente se conecta — el estado de la placa persiste entre clientes.
"""

import argparse
import os
import socket
import sys
import threading
import time

try:
    import serial
except ImportError:
    print('Falta pyserial. Instálalo con:  pip install --user pyserial')
    sys.exit(1)

# Errores que indican que el puerto serie ha muerto. En Linux algunos
# fallos llegan como termios.error, que no hereda de SerialException.
ERRORES_SERIE = [serial.SerialException, OSError]
try:
    import termios
    ERRORES_SERIE.append(termios.error)
except ImportError:          # Windows no tiene termios
    pass
ERRORES_SERIE = tuple(ERRORES_SERIE)


def atender_cliente(cliente, con):
    """Copia datos en ambos sentidos hasta que el cliente se desconecte.

    Devuelve False si el que falló fue el puerto serie (Arduino
    desenchufado), True si simplemente se fue el cliente.
    """
    parar = threading.Event()
    serie_rota = threading.Event()

    def serie_a_tcp():
        while not parar.is_set():
            try:
                datos = con.read(con.in_waiting or 1)
            except ERRORES_SERIE:
                serie_rota.set()
                parar.set()
                break
            if datos:
                try:
                    cliente.sendall(datos)
                except OSError:
                    parar.set()
                    break

    hilo = threading.Thread(target=serie_a_tcp, daemon=True)
    hilo.start()

    cliente.settimeout(0.5)
    try:
        while not parar.is_set():
            try:
                datos = cliente.recv(1024)
            except socket.timeout:
                continue
            except OSError:
                break
            if not datos:               # el cliente cerró la conexión
                break
            try:
                con.write(datos)
            except ERRORES_SERIE:
                serie_rota.set()
                break
    finally:
        parar.set()
        try:
            cliente.close()
        except OSError:
            pass
        hilo.join(timeout=1)

    return not serie_rota.is_set()


def modo_inverso(con, destino):
    """El puente se conecta a la CLI (que escucha), en vez de al revés.

    Esquiva el firewall de Windows: WSL->Windows suele estar bloqueado,
    pero Windows->WSL está permitido.
    """
    host, _, puerto = destino.rpartition(':')
    if not host or not puerto.isdigit():
        print('Formato de -c: IP:puerto, p. ej. 172.17.130.5:8765')
        print('La IP de WSL se ve desde Ubuntu con:  hostname -I')
        sys.exit(1)
    objetivo = (host, int(puerto))

    print(f'Modo inverso: conectando a {host}:{puerto} ...')
    print('(en WSL debe estar corriendo: '
          f'python3 panel_arduino_cli.py -p escuchar://:{puerto})')
    print('(Ctrl+C para terminar)')

    avisado = False
    try:
        while True:
            try:
                cliente = socket.create_connection(objetivo, timeout=3)
            except OSError:
                if not avisado:
                    print(f'Todavía no responde {host}:{puerto}; '
                          'reintento cada 2 s...')
                    avisado = True
                time.sleep(2)
                continue
            avisado = False
            print(f'Conectado a {host}:{puerto}')
            try:
                con.reset_input_buffer()
            except ERRORES_SERIE:
                cliente.close()
                break
            if not atender_cliente(cliente, con):
                break
            print('La CLI se desconectó. Reintentando conexión...')
    except KeyboardInterrupt:
        print('\nCerrando puente.')
        return
    print('Se perdió el puerto serie (¿Arduino desenchufado?).')
    print('Reconecta el USB y vuelve a lanzar el puente — ojo: el '
          'número de COM puede cambiar.')


def main():
    parser = argparse.ArgumentParser(
        description='Sirve un puerto COM/serie por TCP (para WSL sin admin).')
    parser.add_argument('puerto_com',
                        help='puerto serie a compartir, p. ej. COM3 '
                             'o /dev/ttyUSB0')
    parser.add_argument('-b', '--baudios', type=int, default=9600)
    parser.add_argument('-t', '--tcp', type=int, default=8765,
                        help='puerto TCP de escucha (por defecto 8765)')
    parser.add_argument('-d', '--direccion', default='0.0.0.0',
                        help='dirección de escucha (por defecto todas; usa '
                             '127.0.0.1 con WSL en modo mirrored)')
    parser.add_argument('-c', '--conectar', metavar='IP:PUERTO',
                        help='modo inverso: conectarse a la CLI que escucha '
                             'en WSL (esquiva el firewall de Windows), '
                             'p. ej. -c 172.17.130.5:8765')
    args = parser.parse_args()

    try:
        con = serial.Serial(args.puerto_com, args.baudios, timeout=0.1)
    except serial.SerialException as e:
        print(f'No se pudo abrir {args.puerto_com}: {e}')
        print('Comprueba el número de COM con: '
              'python -m serial.tools.list_ports -v')
        sys.exit(1)

    if args.conectar:
        try:
            modo_inverso(con, args.conectar)
        finally:
            try:
                con.close()
            except ERRORES_SERIE:
                pass
        return

    servidor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    if os.name == 'nt' and hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
        # En Windows, SO_REUSEADDR permitiria que dos puentes escuchen en el
        # mismo puerto sin error (y los clientes caerian en uno al azar);
        # con EXCLUSIVE el segundo puente falla con un mensaje claro.
        servidor.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
    else:
        servidor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        servidor.bind((args.direccion, args.tcp))
    except OSError as e:
        print(f'No se pudo escuchar en {args.direccion}:{args.tcp}: {e}')
        print('¿Hay otro puente ya en marcha? Elige otro puerto con -t.')
        sys.exit(1)
    servidor.listen(1)
    # Timeout en accept(): en Windows, un accept() bloqueante ignora el
    # Ctrl+C hasta que llega un cliente; con timeout el bucle vuelve a
    # Python cada segundo y el Ctrl+C funciona de verdad.
    servidor.settimeout(1.0)

    print(f'Puente listo: {args.puerto_com} @ {args.baudios} baudios '
          f'<-> TCP {args.direccion}:{args.tcp}')
    print('Conecta desde WSL con: '
          f'python3 panel_arduino_cli.py -p socket://<IP>:{args.tcp}')
    print('(Ctrl+C para terminar)')

    try:
        while True:
            try:
                cliente, origen = servidor.accept()
            except socket.timeout:
                continue
            print(f'Cliente conectado desde {origen[0]}:{origen[1]}')
            # Descarta la telemetría acumulada mientras no había cliente,
            # para no soltarle una ráfaga de datos viejos al conectarse.
            try:
                con.reset_input_buffer()
            except ERRORES_SERIE:
                cliente.close()
                break
            if not atender_cliente(cliente, con):
                break
            print('Cliente desconectado. Esperando otro...')
    except KeyboardInterrupt:
        print('\nCerrando puente.')
    else:
        print('Se perdió el puerto serie (¿Arduino desenchufado?).')
        print('Reconecta el USB y vuelve a lanzar el puente — ojo: el '
              'número de COM puede cambiar.')
    finally:
        servidor.close()
        try:
            con.close()
        except ERRORES_SERIE:
            pass


if __name__ == '__main__':
    main()
