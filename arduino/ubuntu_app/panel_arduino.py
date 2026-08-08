#!/usr/bin/env python3
"""Panel Arduino — aplicación de escritorio para Ubuntu.

Se conecta por USB al Arduino UNO (pulsador + LED + OLED) o al MEGA 2560
(encoder + servo + OLED + placa solar) y permite:

  - Cambiar el modo del LED del UNO con botones (comandos M0..M3).
  - Mover el servo del MEGA con un deslizador (comando A<ángulo>) y
    centrarlo (comando C).
  - Ver en tiempo real el modo del LED, el ángulo del servo y el voltaje
    de la placa solar (líneas MODO:n, ANGULO:n y SOLAR:v del puerto serie).

Requisitos en Ubuntu:
    sudo apt install python3-tk python3-serial
    (o: pip install pyserial)

Ejecución:
    python3 panel_arduino.py
"""

import glob
import queue
import threading
import tkinter as tk
from tkinter import messagebox, ttk

try:
    import serial
    from serial.tools import list_ports
except ImportError:  # pyserial no instalado
    serial = None
    list_ports = None

BAUDIOS = 9600
NOMBRES_MODO = ['Apagado', 'Encendido', 'Parpadeo lento', 'Parpadeo rápido']


def puertos_disponibles():
    """Devuelve los puertos serie candidatos (Arduino suele ser ttyUSB/ttyACM)."""
    puertos = []
    if list_ports is not None:
        puertos = [p.device for p in list_ports.comports()]
    if not puertos:  # plan B por si list_ports no ve nada
        puertos = sorted(glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*'))
    return puertos


class PanelArduino(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('Panel Arduino')
        self.minsize(520, 560)

        self.conexion = None
        self.hilo_lectura = None
        self.leyendo = False
        self.cola_lineas = queue.Queue()
        self._ignorar_slider = False

        self._construir_ui()
        self.refrescar_puertos()
        self.after(100, self._procesar_cola)
        self.protocol('WM_DELETE_WINDOW', self._al_cerrar)

        if serial is None:
            messagebox.showerror(
                'Falta pyserial',
                'No está instalado el módulo pyserial.\n\n'
                'Instálalo con:\n'
                '  sudo apt install python3-serial\n'
                'o bien:\n'
                '  pip install pyserial',
            )

    # ------------------------------------------------------------- UI
    def _construir_ui(self):
        contenedor = ttk.Frame(self, padding=12)
        contenedor.pack(fill='both', expand=True)

        # --- Conexión ---
        marco_con = ttk.LabelFrame(contenedor, text='Conexión', padding=8)
        marco_con.pack(fill='x')

        ttk.Label(marco_con, text='Puerto:').grid(row=0, column=0, sticky='w')
        self.combo_puerto = ttk.Combobox(marco_con, state='readonly', width=18)
        self.combo_puerto.grid(row=0, column=1, padx=6)

        ttk.Button(marco_con, text='Buscar', command=self.refrescar_puertos)\
            .grid(row=0, column=2, padx=2)
        self.boton_conectar = ttk.Button(
            marco_con, text='Conectar', command=self.alternar_conexion)
        self.boton_conectar.grid(row=0, column=3, padx=2)

        self.etiqueta_estado = ttk.Label(marco_con, text='Desconectado',
                                         foreground='red')
        self.etiqueta_estado.grid(row=0, column=4, padx=8)

        # --- UNO: LED ---
        marco_led = ttk.LabelFrame(
            contenedor, text='Arduino UNO — LED (pulsador y OLED)', padding=8)
        marco_led.pack(fill='x', pady=(10, 0))

        self.etiqueta_modo = ttk.Label(marco_led, text='Modo: —',
                                       font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_modo.pack(anchor='w')

        fila_botones = ttk.Frame(marco_led)
        fila_botones.pack(fill='x', pady=(6, 0))
        for i, nombre in enumerate(NOMBRES_MODO):
            ttk.Button(fila_botones, text=nombre,
                       command=lambda n=i: self.enviar(f'M{n}'))\
                .pack(side='left', expand=True, fill='x', padx=2)

        # --- MEGA: servo + solar ---
        marco_mega = ttk.LabelFrame(
            contenedor, text='Arduino MEGA — Servo y placa solar', padding=8)
        marco_mega.pack(fill='x', pady=(10, 0))

        self.etiqueta_angulo = ttk.Label(marco_mega, text='Ángulo: —',
                                         font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_angulo.pack(anchor='w')

        self.slider_angulo = ttk.Scale(
            marco_mega, from_=0, to=180, orient='horizontal',
            command=self._slider_movido)
        self.slider_angulo.set(90)
        self.slider_angulo.pack(fill='x', pady=(4, 2))
        # Enviar solo al soltar, para no inundar el puerto serie
        self.slider_angulo.bind('<ButtonRelease-1>', self._slider_soltado)

        ttk.Button(marco_mega, text='Centrar servo (90°)',
                   command=lambda: self.enviar('C')).pack(anchor='w')

        fila_solar = ttk.Frame(marco_mega)
        fila_solar.pack(fill='x', pady=(8, 0))
        ttk.Label(fila_solar, text='Placa solar:').pack(side='left')
        self.etiqueta_solar = ttk.Label(fila_solar, text='— V',
                                        font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_solar.pack(side='left', padx=6)
        self.barra_solar = ttk.Progressbar(marco_mega, maximum=5.0)
        self.barra_solar.pack(fill='x', pady=(4, 0))

        # --- Consola ---
        marco_log = ttk.LabelFrame(contenedor, text='Monitor serie', padding=8)
        marco_log.pack(fill='both', expand=True, pady=(10, 0))

        self.texto_log = tk.Text(marco_log, height=10, state='disabled',
                                 wrap='none')
        barra = ttk.Scrollbar(marco_log, command=self.texto_log.yview)
        self.texto_log.configure(yscrollcommand=barra.set)
        barra.pack(side='right', fill='y')
        self.texto_log.pack(fill='both', expand=True)

    # ------------------------------------------------------ Conexión
    def refrescar_puertos(self):
        puertos = puertos_disponibles()
        self.combo_puerto['values'] = puertos
        if puertos and not self.combo_puerto.get():
            self.combo_puerto.set(puertos[0])
        if not puertos:
            self.registrar('No se ha encontrado ningún puerto. ¿Está '
                           'conectado el Arduino por USB?')

    def alternar_conexion(self):
        if self.conexion is not None:
            self.desconectar()
        else:
            self.conectar()

    def conectar(self):
        if serial is None:
            return
        puerto = self.combo_puerto.get()
        if not puerto:
            messagebox.showwarning('Sin puerto',
                                   'Selecciona un puerto (botón Buscar).')
            return
        try:
            self.conexion = serial.Serial(puerto, BAUDIOS, timeout=1)
        except serial.SerialException as e:
            texto = str(e)
            if 'Permission' in texto or 'permission' in texto:
                texto += ('\n\nEn Ubuntu, añade tu usuario al grupo dialout:\n'
                          '  sudo usermod -a -G dialout $USER\n'
                          'y vuelve a iniciar sesión.')
            messagebox.showerror('Error al conectar', texto)
            self.conexion = None
            return

        self.leyendo = True
        self.hilo_lectura = threading.Thread(target=self._bucle_lectura,
                                             daemon=True)
        self.hilo_lectura.start()

        self.boton_conectar.configure(text='Desconectar')
        self.etiqueta_estado.configure(text=f'Conectado a {puerto}',
                                       foreground='green')
        self.registrar(f'Conectado a {puerto} @ {BAUDIOS} baudios')
        # El Arduino se reinicia al abrir el puerto: pedir estado tras 2 s
        self.after(2000, lambda: self.enviar('?'))

    def desconectar(self):
        self.leyendo = False
        if self.conexion is not None:
            try:
                self.conexion.close()
            except Exception:
                pass
            self.conexion = None
        self.boton_conectar.configure(text='Conectar')
        self.etiqueta_estado.configure(text='Desconectado', foreground='red')
        self.registrar('Desconectado')

    def enviar(self, comando):
        if self.conexion is None:
            self.registrar(f'(sin conexión) no se envió: {comando}')
            return
        try:
            self.conexion.write((comando + '\n').encode('ascii'))
            self.registrar(f'-> {comando}')
        except serial.SerialException as e:
            self.registrar(f'Error al enviar: {e}')
            self.desconectar()

    # ------------------------------------------------------- Lectura
    def _bucle_lectura(self):
        while self.leyendo and self.conexion is not None:
            try:
                linea = self.conexion.readline()
            except (serial.SerialException, OSError):
                self.cola_lineas.put('__ERROR__')
                break
            if linea:
                self.cola_lineas.put(
                    linea.decode('utf-8', errors='replace').strip())

    def _procesar_cola(self):
        try:
            while True:
                linea = self.cola_lineas.get_nowait()
                if linea == '__ERROR__':
                    self.registrar('Se perdió la conexión con el Arduino.')
                    self.desconectar()
                else:
                    self._procesar_linea(linea)
        except queue.Empty:
            pass
        self.after(100, self._procesar_cola)

    def _procesar_linea(self, linea):
        if not linea:
            return
        self.registrar(f'<- {linea}')

        if linea.startswith('MODO:'):
            try:
                modo = int(linea.split(':', 1)[1])
                self.etiqueta_modo.configure(
                    text=f'Modo: {modo} — {NOMBRES_MODO[modo]}')
            except (ValueError, IndexError):
                pass
        elif linea.startswith('ANGULO:'):
            try:
                angulo = int(linea.split(':', 1)[1])
                self.etiqueta_angulo.configure(text=f'Ángulo: {angulo}°')
                self._ignorar_slider = True
                self.slider_angulo.set(angulo)
                self._ignorar_slider = False
            except ValueError:
                pass
        elif linea.startswith('SOLAR:'):
            try:
                voltios = float(linea.split(':', 1)[1])
                self.etiqueta_solar.configure(text=f'{voltios:.2f} V')
                self.barra_solar['value'] = voltios
            except ValueError:
                pass

    # -------------------------------------------------------- Slider
    def _slider_movido(self, _valor):
        # Mientras se arrastra solo actualizamos la etiqueta local
        if not self._ignorar_slider:
            self.etiqueta_angulo.configure(
                text=f'Ángulo: {int(float(self.slider_angulo.get()))}°')

    def _slider_soltado(self, _evento):
        self.enviar(f'A{int(float(self.slider_angulo.get()))}')

    # ------------------------------------------------------------ Log
    def registrar(self, texto):
        self.texto_log.configure(state='normal')
        self.texto_log.insert('end', texto + '\n')
        self.texto_log.see('end')
        # Limitar el log a las últimas 500 líneas
        lineas = int(self.texto_log.index('end-1c').split('.')[0])
        if lineas > 500:
            self.texto_log.delete('1.0', f'{lineas - 500}.0')
        self.texto_log.configure(state='disabled')

    def _al_cerrar(self):
        self.desconectar()
        self.destroy()


if __name__ == '__main__':
    PanelArduino().mainloop()
