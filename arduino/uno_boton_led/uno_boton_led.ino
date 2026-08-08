/*
 * uno_boton_led.ino — Arduino UNO
 *
 * Pulsador + LED + pantalla OLED SSD1306.
 * Cada pulsación (o un comando por el puerto serie) cambia el modo del LED:
 *   0 = apagado
 *   1 = encendido fijo
 *   2 = parpadeo lento (500 ms)
 *   3 = parpadeo rápido (100 ms)
 * La OLED muestra el modo actual en grande.
 *
 * Cableado:
 *   - LED: pata larga (ánodo) -> resistencia 220 Ω -> pin 9
 *          pata corta (cátodo) -> GND
 *   - Pulsador: una pata -> pin 2, la pata diagonal -> GND
 *     (se usa la resistencia pull-up interna, no hace falta externa)
 *   - OLED SSD1306 (I2C):
 *       VCC -> 5V   GND -> GND   SDA -> A4   SCL -> A5
 *
 * Comandos por serie (9600 baudios), pensados para la app de escritorio:
 *   M0 / M1 / M2 / M3  -> fija el modo directamente
 *   ?                  -> reenvía el estado actual
 * El estado se publica como lineas "MODO:n" para que sea facil de parsear.
 *
 * Librerías (Gestor de librerías del IDE): Adafruit GFX y Adafruit SH110X
 * (o Adafruit SSD1306 si comentas PANTALLA_SH1106).
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
// --- Elige el chip de tu pantalla OLED ---
// Con PANTALLA_SH1106 activo usa la libreria "Adafruit SH110X" (pantallas
// de 1.3" o mas que muestran "nieve" con la SSD1306). Comenta la linea
// para volver a SSD1306 (las tipicas de 0.96").
#define PANTALLA_SH1106

#ifdef PANTALLA_SH1106
#include <Adafruit_SH110X.h>
#else
#include <Adafruit_SSD1306.h>
#endif

const uint8_t PIN_LED = 9;     // pin con PWM, por si quieres regular brillo
const uint8_t PIN_BOTON = 2;

const unsigned long DEBOUNCE_MS = 30;

const uint8_t ANCHO_OLED = 128;
const uint8_t ALTO_OLED  = 64;      // si tu OLED es de 128x32, cambia a 32
#ifdef PANTALLA_SH1106
Adafruit_SH1106G oled(ANCHO_OLED, ALTO_OLED, &Wire, -1);
#define COLOR_OLED SH110X_WHITE
#else
Adafruit_SSD1306 oled(ANCHO_OLED, ALTO_OLED, &Wire, -1);
#define COLOR_OLED SSD1306_WHITE
#endif

// begin() cambia de firma entre las dos librerias
bool iniciarOled() {
#ifdef PANTALLA_SH1106
  return oled.begin(0x3C, true);   // direccion, reset
#else
  return oled.begin(SSD1306_SWITCHCAPVCC, 0x3C);
#endif
}
bool hayOled = false;

uint8_t modo = 0;                    // 0..3
bool estadoLed = false;
unsigned long ultimoParpadeo = 0;

// Variables para el antirrebote del pulsador
bool lecturaEstable = HIGH;          // HIGH = suelto (pull-up)
bool ultimaLectura = HIGH;
unsigned long ultimoCambio = 0;

const char* nombreModo(uint8_t m) {
  switch (m) {
    case 0: return "Apagado";
    case 1: return "Encendido";
    case 2: return "Lento";
    default: return "Rapido";
  }
}

void setup() {
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  Serial.begin(9600);

  // 0x3C es la dirección I2C habitual de estos módulos (a veces 0x3D).
  // Si no hay OLED conectada el programa sigue funcionando igualmente.
  hayOled = iniciarOled();
  if (!hayOled) {
    Serial.println(F("Aviso: no se encuentra la OLED (se sigue sin ella)."));
  }

  Serial.println(F("Boton + LED listo. Pulsa el boton o envia M0..M3."));
  publicarEstado();
}

void loop() {
  leerBoton();
  leerSerie();
  actualizarLed();
}

void cambiarModo(uint8_t nuevo) {
  modo = nuevo % 4;
  publicarEstado();
}

void publicarEstado() {
  Serial.print(F("MODO:"));
  Serial.println(modo);
  dibujarPantalla();
}

void leerBoton() {
  bool lectura = digitalRead(PIN_BOTON);

  if (lectura != ultimaLectura) {
    ultimoCambio = millis();          // hubo un cambio, arranca el temporizador
    ultimaLectura = lectura;
  }

  if (millis() - ultimoCambio > DEBOUNCE_MS && lectura != lecturaEstable) {
    lecturaEstable = lectura;
    if (lecturaEstable == LOW) {      // flanco de pulsación
      cambiarModo(modo + 1);
    }
  }
}

void leerSerie() {
  while (Serial.available() > 0) {
    char c = Serial.read();
    if (c == 'M' || c == 'm') {
      // Espera brevemente el dígito que acompaña a la M
      unsigned long inicio = millis();
      while (Serial.available() == 0 && millis() - inicio < 50) {}
      if (Serial.available() > 0) {
        char d = Serial.read();
        if (d >= '0' && d <= '3') {
          cambiarModo(d - '0');
        }
      }
    } else if (c == '?') {
      publicarEstado();
    }
  }
}

void actualizarLed() {
  switch (modo) {
    case 0:
      digitalWrite(PIN_LED, LOW);
      break;
    case 1:
      digitalWrite(PIN_LED, HIGH);
      break;
    case 2:
      parpadear(500);
      break;
    case 3:
      parpadear(100);
      break;
  }
}

void parpadear(unsigned long intervaloMs) {
  if (millis() - ultimoParpadeo >= intervaloMs) {
    ultimoParpadeo = millis();
    estadoLed = !estadoLed;
    digitalWrite(PIN_LED, estadoLed ? HIGH : LOW);
  }
}

void dibujarPantalla() {
  if (!hayOled) {
    return;
  }
  oled.clearDisplay();
  oled.setTextColor(COLOR_OLED);

  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print(F("Modo LED ("));
  oled.print(modo);
  oled.println(F("/3):"));

  oled.setTextSize(2);
  oled.setCursor(0, 20);
  oled.println(nombreModo(modo));

  // Barra de progreso segun el modo (0 a 3)
  const uint8_t altoBarra = 8;
  uint8_t ancho = map(modo, 0, 3, 0, ANCHO_OLED);
  oled.drawRect(0, ALTO_OLED - altoBarra, ANCHO_OLED, altoBarra, COLOR_OLED);
  oled.fillRect(0, ALTO_OLED - altoBarra, ancho, altoBarra, COLOR_OLED);

  oled.display();
}
