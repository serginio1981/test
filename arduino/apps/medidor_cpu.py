#!/usr/bin/env python3
"""Medidor analógico de CPU — la aguja del servo marca el uso de CPU del PC.

Convierte el servo de la estación MEGA en un vúmetro físico: 0% de CPU son
0 grados y 100% son 180. Pega una flecha de cartón al eje del servo y tendrás
un medidor analógico de escritorio.

Dónde ejecutarlo:
  - En WINDOWS (recomendado): mide la CPU real del PC y habla directo con
    el COM del Arduino. Cierra antes el puente TCP si está corriendo.
        python medidor_cpu.py -p COM4
  - En WSL/Linux: mide la CPU de esa máquina Linux (en WSL2, la de la
    máquina virtual, no la de Windows). Acepta los mismos puertos que la
    CLI, incluido el modo inverso:
        python3 medidor_cpu.py -p escuchar://:8765
    (y en Windows: python puente_com_tcp.py COM4 -c 127.0.0.1:8765)

Opciones:
    -p / --puerto     igual que en panel_arduino_cli.py
    -i / --intervalo  segundos entre medidas (por defecto 1.0)
    -s / --suavizado  0..1, cuánto pesa la medida nueva (por defecto 0.4;
                      1 = aguja nerviosa sin suavizar)
    -n / --veces      número de medidas y salir (0 = sin fin)

Sin dependencias extra en Windows (usa la API del sistema via ctypes);
en Linux lee /proc/stat. pyserial hace falta en ambos, como siempre.
"""

import argparse
import sys
import time

import panel_arduino_cli as cli      # reutiliza puertos, apertura y errores

if cli.serial is None:
    print('Falta pyserial. Instálalo con:  pip install --user pyserial')
    sys.exit(1)


# ------------------------------------------------------- medida de CPU
if sys.platform.startswith('win'):
    import ctypes

    class _FILETIME(ctypes.Structure):
        _fields_ = [('lo', ctypes.c_uint32), ('hi', ctypes.c_uint32)]

    def _tiempos_cpu():
        """(ocupado, total) acumulados desde el arranque, en unidades de 100ns."""
        idle, kernel, user = _FILETIME(), _FILETIME(), _FILETIME()
        ctypes.windll.kernel32.GetSystemTimes(ctypes.byref(idle),
                                              ctypes.byref(kernel),
                                              ctypes.byref(user))
        def valor(ft):
            return (ft.hi << 32) | ft.lo
        # kernel incluye el tiempo idle, así que total = kernel + user
        total = valor(kernel) + valor(user)
        return total - valor(idle), total
else:
    def _tiempos_cpu():
        """(ocupado, total) leídos de /proc/stat (Linux/WSL)."""
        with open('/proc/stat') as f:
            campos = [int(x) for x in f.readline().split()[1:]]
        idle = campos[3] + (campos[4] if len(campos) > 4 else 0)  # idle+iowait
        total = sum(campos)
        return total - idle, total


class MedidorCpu:
    def __init__(self):
        self._ocupado, self._total = _tiempos_cpu()

    def porcentaje(self):
        ocupado, total = _tiempos_cpu()
        d_ocupado = ocupado - self._ocupado
        d_total = total - self._total
        self._ocupado, self._total = ocupado, total
        if d_total <= 0:
            return 0.0
        return max(0.0, min(100.0, 100.0 * d_ocupado / d_total))


def barra(pct, ancho=30):
    llenos = int(pct / 100 * ancho)
    return '#' * llenos + '-' * (ancho - llenos)


def main():
    parser = argparse.ArgumentParser(
        description='Muestra el uso de CPU en el servo de la estación '
                    '(0%% = 0 grados, 100%% = 180).')
    parser.add_argument('-p', '--puerto',
                        help='puerto serie, socket://... o escuchar://... '
                             '(autodetectado si se omite)')
    parser.add_argument('-b', '--baudios', type=int, default=cli.BAUDIOS_DEFECTO)
    parser.add_argument('-i', '--intervalo', type=float, default=1.0)
    parser.add_argument('-s', '--suavizado', type=float, default=0.4,
                        help='peso de la medida nueva, 0..1 (1 = sin suavizar)')
    parser.add_argument('-n', '--veces', type=int, default=0,
                        help='medidas a enviar y salir (0 = sin fin)')
    args = parser.parse_args()

    puerto = cli.elegir_puerto(args.puerto)
    con = cli.abrir(puerto, args.baudios, None)

    medidor = MedidorCpu()
    alfa = max(0.0, min(1.0, args.suavizado))
    suavizada = None
    hechas = 0

    origen = 'Windows' if sys.platform.startswith('win') else 'Linux/WSL'
    print(f'Midiendo CPU de {origen} cada {args.intervalo:g} s. '
          'Ctrl+C para terminar (deja el servo centrado).')

    try:
        time.sleep(args.intervalo)       # primera ventana de medida
        while True:
            pct = medidor.porcentaje()
            suavizada = pct if suavizada is None else \
                alfa * pct + (1 - alfa) * suavizada
            angulo = round(suavizada * 1.8)          # 0..100% -> 0..180
            try:
                con.write(f'A{angulo}\n'.encode('ascii'))
            except cli.serial.SerialException as e:
                print(f'\nSe perdió la conexión: {e}')
                sys.exit(1)
            print(f'\rCPU {suavizada:5.1f}% [{barra(suavizada)}] '
                  f'servo {angulo:3d}° ', end='', flush=True)
            hechas += 1
            if args.veces and hechas >= args.veces:
                print()
                break
            time.sleep(args.intervalo)
    except KeyboardInterrupt:
        print()
    finally:
        try:
            con.write(b'C\n')            # aguja al centro al salir
            con.close()
        except Exception:
            pass


if __name__ == '__main__':
    main()
