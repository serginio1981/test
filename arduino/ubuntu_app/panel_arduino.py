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


PLACAS = ['Automática (mostrar todo)', 'Arduino MEGA 2560', 'Arduino UNO']


def puertos_disponibles():
    """[(dispositivo, descripción), ...] — como el menú de puertos del IDE."""
    puertos = []
    if list_ports is not None:
        puertos = [(p.device, p.description or '')
                   for p in list_ports.comports()]
    if not puertos:  # plan B por si list_ports no ve nada
        puertos = [(d, '') for d in
                   sorted(glob.glob('/dev/ttyUSB*') + glob.glob('/dev/ttyACM*'))]
    return puertos


class PanelArduino(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('Panel Arduino')
        self.minsize(600, 700)

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

        # --- Administración: placa, puerto y velocidad (como el IDE) ---
        marco_con = ttk.LabelFrame(contenedor,
                                   text='Administración de conexión',
                                   padding=8)
        marco_con.pack(fill='x')

        ttk.Label(marco_con, text='Placa:').grid(row=0, column=0, sticky='w')
        self.combo_placa = ttk.Combobox(marco_con, state='readonly',
                                        width=26, values=PLACAS)
        self.combo_placa.set(PLACAS[0])
        self.combo_placa.grid(row=0, column=1, padx=6, sticky='w')
        self.combo_placa.bind('<<ComboboxSelected>>', self._aplicar_placa)

        self.etiqueta_estado = ttk.Label(marco_con, text='Desconectado',
                                         foreground='red')
        self.etiqueta_estado.grid(row=0, column=2, columnspan=2,
                                  padx=8, sticky='w')

        ttk.Label(marco_con, text='Puerto:').grid(row=1, column=0,
                                                  sticky='w', pady=(6, 0))
        # Editable: ademas de elegir un puerto detectado se puede escribir
        # una URL de pyserial, p. ej. socket://192.168.1.10:8765
        self.combo_puerto = ttk.Combobox(marco_con, width=36)
        self.combo_puerto.grid(row=1, column=1, padx=6, pady=(6, 0),
                               sticky='w')
        ttk.Button(marco_con, text='Buscar', command=self.refrescar_puertos)\
            .grid(row=1, column=2, padx=2, pady=(6, 0))
        self.boton_conectar = ttk.Button(
            marco_con, text='Conectar', command=self.alternar_conexion)
        self.boton_conectar.grid(row=1, column=3, padx=2, pady=(6, 0))

        ttk.Label(marco_con, text='Baudios:').grid(row=2, column=0,
                                                   sticky='w', pady=(6, 0))
        self.combo_baudios = ttk.Combobox(
            marco_con, state='readonly', width=10,
            values=['9600', '19200', '38400', '57600', '115200'])
        self.combo_baudios.set(str(BAUDIOS))
        self.combo_baudios.grid(row=2, column=1, padx=6, pady=(6, 0),
                                sticky='w')

        # --- UNO: LED ---
        self.marco_led = ttk.LabelFrame(
            contenedor, text='Arduino UNO — LED (pulsador y OLED)', padding=8)
        self.marco_led.pack(fill='x', pady=(10, 0))

        self.etiqueta_modo = ttk.Label(self.marco_led, text='Modo: —',
                                       font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_modo.pack(anchor='w')

        fila_botones = ttk.Frame(self.marco_led)
        fila_botones.pack(fill='x', pady=(6, 0))
        for i, nombre in enumerate(NOMBRES_MODO):
            ttk.Button(fila_botones, text=nombre,
                       command=lambda n=i: self.enviar(f'M{n}'))\
                .pack(side='left', expand=True, fill='x', padx=2)

        # --- MEGA: servo + solar ---
        self.marco_mega = ttk.LabelFrame(
            contenedor, text='Arduino MEGA — Servo y placa solar', padding=8)
        self.marco_mega.pack(fill='x', pady=(10, 0))

        self.etiqueta_angulo = ttk.Label(self.marco_mega, text='Ángulo: —',
                                         font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_angulo.pack(anchor='w')

        self.slider_angulo = ttk.Scale(
            self.marco_mega, from_=0, to=180, orient='horizontal',
            command=self._slider_movido)
        self.slider_angulo.set(90)
        self.slider_angulo.pack(fill='x', pady=(4, 2))
        # Enviar solo al soltar, para no inundar el puerto serie
        self.slider_angulo.bind('<ButtonRelease-1>', self._slider_soltado)

        ttk.Button(self.marco_mega, text='Centrar servo (90°)',
                   command=lambda: self.enviar('C')).pack(anchor='w')

        fila_solar = ttk.Frame(self.marco_mega)
        fila_solar.pack(fill='x', pady=(8, 0))
        ttk.Label(fila_solar, text='Placa solar:').pack(side='left')
        self.etiqueta_solar = ttk.Label(fila_solar, text='— V',
                                        font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_solar.pack(side='left', padx=6)
        self.barra_solar = ttk.Progressbar(self.marco_mega, maximum=5.0)
        self.barra_solar.pack(fill='x', pady=(4, 0))

        # --- Multiusos: MPU-6050 (alarma / nivel / theremin) ---
        self.marco_multi = ttk.LabelFrame(
            contenedor, text='Multiusos MPU-6050 (alarma, nivel, theremin)',
            padding=8)
        self.marco_multi.pack(fill='x', pady=(10, 0))

        self.etiqueta_multi = ttk.Label(self.marco_multi, text='Modo: —',
                                        font=('TkDefaultFont', 12, 'bold'))
        self.etiqueta_multi.pack(anchor='w')

        fila_multi = ttk.Frame(self.marco_multi)
        fila_multi.pack(fill='x', pady=(6, 0))
        for i, nombre in enumerate(['Alarma', 'Nivel', 'Theremin']):
            ttk.Button(fila_multi, text=nombre,
                       command=lambda n=i: self.enviar(f'M{n}'))\
                .pack(side='left', expand=True, fill='x', padx=2)
        ttk.Button(fila_multi, text='Pulsar (armar/accion)',
                   command=lambda: self.enviar('P'))\
            .pack(side='left', expand=True, fill='x', padx=2)

        # --- Consola ---
        self.marco_log = ttk.LabelFrame(contenedor, text='Monitor serie', padding=8)
        self.marco_log.pack(fill='both', expand=True, pady=(10, 0))

        self.texto_log = tk.Text(self.marco_log, height=10, state='disabled',
                                 wrap='none')
        barra = ttk.Scrollbar(self.marco_log, command=self.texto_log.yview)
        self.texto_log.configure(yscrollcommand=barra.set)
        barra.pack(side='right', fill='y')
        self.texto_log.pack(fill='both', expand=True)

    # ------------------------------------------------------ Conexión
    def refrescar_puertos(self):
        self._puertos = {}
        for dispositivo, descripcion in puertos_disponibles():
            texto = (f'{dispositivo} — {descripcion}' if descripcion
                     else dispositivo)
            self._puertos[texto] = dispositivo
        self.combo_puerto['values'] = list(self._puertos)
        if self._puertos and not self.combo_puerto.get():
            self.combo_puerto.set(next(iter(self._puertos)))
        if not self._puertos:
            self.registrar('No se ha encontrado ningún puerto. ¿Está '
                           'conectado el Arduino por USB?')

    def _aplicar_placa(self, _evento=None):
        """Muestra los paneles que corresponden a la placa elegida."""
        placa = self.combo_placa.get()
        for marco in (self.marco_led, self.marco_mega, self.marco_multi):
            marco.pack_forget()
        if 'UNO' in placa:
            visibles = (self.marco_led,)
        elif 'MEGA' in placa:
            visibles = (self.marco_mega, self.marco_multi)
        else:
            visibles = (self.marco_led, self.marco_mega, self.marco_multi)
        for marco in visibles:
            marco.pack(fill='x', pady=(10, 0), before=self.marco_log)
        self.registrar(f'Placa seleccionada: {placa}')

    def alternar_conexion(self):
        if self.conexion is not None:
            self.desconectar()
        else:
            self.conectar()

    def conectar(self):
        if serial is None:
            return
        # (la velocidad se toma del selector de baudios al conectar)
        texto = self.combo_puerto.get().strip()
        puerto = getattr(self, '_puertos', {}).get(texto) or \
            texto.split(' — ')[0]
        if not puerto:
            messagebox.showwarning('Sin puerto',
                                   'Selecciona un puerto (botón Buscar).')
            return
        try:
            baudios = int(self.combo_baudios.get() or BAUDIOS)
            if '://' in puerto:
                self.conexion = serial.serial_for_url(puerto,
                                                      baudrate=baudios,
                                                      timeout=1)
            else:
                self.conexion = serial.Serial(puerto, baudios, timeout=1)
        except (serial.SerialException, OSError, ValueError) as e:
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
        self.registrar(f'Conectado a {puerto} @ {baudios} baudios')
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

        if linea.startswith('EVENTO:ALARMA'):
            self.etiqueta_multi.configure(
                text='🚨 ALARMA: MOVIMIENTO DETECTADO', foreground='red')
            self._sonar_alarma()
        elif linea.startswith('MODO:'):
            partes = linea.split(':', 1)[1].split()
            try:
                modo = int(partes[0])
            except (ValueError, IndexError):
                return
            if len(partes) > 1:          # sketch multiusos: "MODO:0 ALARMA"
                self.etiqueta_multi.configure(
                    text=f'Modo: {partes[1]}', foreground='')
            else:                        # sketch del UNO: "MODO:n"
                try:
                    self.etiqueta_modo.configure(
                        text=f'Modo: {modo} — {NOMBRES_MODO[modo]}')
                except IndexError:
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

    def _sonar_alarma(self):
        """Pitidos de alarma sin bloquear la interfaz."""
        def _beeps():
            try:
                import winsound
                for _ in range(4):
                    winsound.Beep(1000, 180)
                    winsound.Beep(1400, 180)
            except ImportError:
                print('\a', end='', flush=True)
        threading.Thread(target=_beeps, daemon=True).start()

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
