/*
 * mega_panel_control.ino — Arduino MEGA 2560
 *
 * Mini estación de control que usa el resto de tu material:
 *   - Encoder rotativo: girándolo mueves el servo SG90 de 0 a 180 grados.
 *     Pulsando el eje del encoder, el servo vuelve a 90 (centro).
 *   - Pantalla OLED (I2C): muestra el ángulo del servo, el voltaje actual
 *     de la placa solar y una gráfica con el histórico del voltaje de los
 *     últimos 2 minutos (una muestra por segundo, escala fija 0-5 V).
 *   - Placa solar: se lee su voltaje por A0.
 *
 * Comandos por serie (9600 baudios), pensados para la app de escritorio:
 *   A<numero>  -> mueve el servo a ese ángulo (ej. "A135")
 *   C          -> centra el servo (90 grados)
 *   ?          -> reenvía el estado actual
 * El estado se publica como líneas "ANGULO:n" y "SOLAR:v" para que sea
 * fácil de parsear.
 *
 * Cableado (MEGA 2560):
 *   OLED SSD1306 (I2C):
 *     VCC -> 5V   GND -> GND   SDA -> pin 20 (SDA)   SCL -> pin 21 (SCL)
 *   Encoder rotativo:
 *     CLK -> pin 2    DT -> pin 3    SW -> pin 4
 *     +   -> 5V       GND -> GND
 *   Servo SG90:
 *     Cable naranja (señal) -> pin 9
 *     Cable rojo -> 5V       Cable marrón -> GND
 *   Placa solar:
 *     Positivo -> A0          Negativo -> GND
 *     (panel pequeño de <5 V; si tu panel supera 5 V usa un divisor
 *      de tensión con dos resistencias iguales y multiplica x2 la lectura)
 *
 * Librerías necesarias (Gestor de librerías del IDE de Arduino):
 *   - Adafruit GFX Library
 *   - Adafruit SH110X   (pantallas SH1106; es la opcion por defecto)
 *   - Adafruit SSD1306  (solo si comentas PANTALLA_SH1106)
 *   - Servo (viene incluida con el IDE)
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
#include <Servo.h>

// --- Pines ---
const uint8_t PIN_ENCODER_CLK = 2;   // pin con interrupción
const uint8_t PIN_ENCODER_DT  = 3;
const uint8_t PIN_ENCODER_SW  = 4;
const uint8_t PIN_SERVO       = 9;
const uint8_t PIN_SOLAR       = A0;

// --- Pantalla ---
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

// --- Estado ---
bool hayOled = false;                // la estacion funciona aunque no haya
Servo servo;
volatile int angulo = 90;            // lo modifica la interrupción del encoder
const int PASO_GRADOS = 2;           // grados por "clic" del encoder

unsigned long ultimoRefresco = 0;
const unsigned long REFRESCO_MS = 100;

// --- Histórico del voltaje para la gráfica ---
// Una muestra por segundo; 120 muestras = los últimos 2 minutos.
// Se guarda voltios*50 en un byte (0..250 equivale a 0.00..5.00 V).
const uint8_t N_MUESTRAS = 120;
uint8_t historial[N_MUESTRAS];
uint8_t nMuestras = 0;
unsigned long ultimaMuestra = 0;
const unsigned long MUESTREO_MS = 1000;

// Zona de la gráfica en pantalla (mitad inferior)
const uint8_t GRAF_Y = 32;
const uint8_t GRAF_ALTO = 32;

void setup() {
  Serial.begin(9600);

  pinMode(PIN_ENCODER_CLK, INPUT_PULLUP);
  pinMode(PIN_ENCODER_DT, INPUT_PULLUP);
  pinMode(PIN_ENCODER_SW, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_CLK), leerEncoder, FALLING);

  servo.attach(PIN_SERVO);
  servo.write(angulo);

  // 0x3C es la dirección I2C habitual de estos módulos (a veces 0x3D).
  // Si la OLED falla, la estacion sigue: servo, encoder y comandos serie
  // funcionan igual, solo que sin pantalla.
  hayOled = iniciarOled();
  if (!hayOled) {
    Serial.println(F("Aviso: no se encuentra la OLED (la estacion sigue "
                     "sin pantalla). Revisa cableado o direccion 0x3C/0x3D."));
  } else {
    oled.clearDisplay();
    oled.setTextColor(COLOR_OLED);
    oled.setTextSize(1);
    oled.setCursor(0, 0);
    oled.println(F("Estacion lista"));
    oled.display();
    delay(500);
  }
}

void loop() {
  // Botón del encoder: centra el servo
  if (digitalRead(PIN_ENCODER_SW) == LOW) {
    angulo = 90;
    delay(200);                      // antirrebote sencillo del pulsador
  }

  leerSerie();
  servo.write(angulo);

  if (millis() - ultimoRefresco >= REFRESCO_MS) {
    ultimoRefresco = millis();
    float voltios = analogRead(PIN_SOLAR) * (5.0 / 1023.0);
    if (millis() - ultimaMuestra >= MUESTREO_MS) {
      ultimaMuestra = millis();
      registrarMuestra(voltios);
    }
    dibujarPantalla(angulo, voltios);
    Serial.print(F("ANGULO:"));
    Serial.println(angulo);
    Serial.print(F("SOLAR:"));
    Serial.println(voltios, 2);
  }
}

// Órdenes recibidas desde la app de escritorio (o el monitor serie)
void leerSerie() {
  while (Serial.available() > 0) {
    char c = Serial.read();
    if (c == 'A' || c == 'a') {
      int valor = Serial.parseInt();   // lee el número que sigue a la A
      angulo = constrain(valor, 0, 180);
    } else if (c == 'C' || c == 'c') {
      angulo = 90;
    } else if (c == '?') {
      ultimoRefresco = 0;              // fuerza un refresco inmediato
    }
  }
}

// Interrupción: se dispara en cada flanco de bajada de CLK.
// El estado de DT indica el sentido de giro.
void leerEncoder() {
  if (digitalRead(PIN_ENCODER_DT) == HIGH) {
    angulo += PASO_GRADOS;
  } else {
    angulo -= PASO_GRADOS;
  }
  angulo = constrain(angulo, 0, 180);
}

// Guarda una muestra al final del histórico, desplazando si está lleno
void registrarMuestra(float voltios) {
  uint8_t v = (uint8_t)constrain(voltios * 50.0, 0.0, 250.0);
  if (nMuestras < N_MUESTRAS) {
    historial[nMuestras++] = v;
  } else {
    memmove(historial, historial + 1, N_MUESTRAS - 1);
    historial[N_MUESTRAS - 1] = v;
  }
}

void dibujarPantalla(int ang, float voltios) {
  if (!hayOled) {
    return;
  }
  oled.clearDisplay();

  // Mitad superior: valores actuales
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print(F("Servo: "));
  oled.print(ang);
  oled.print((char)247);             // símbolo de grados

  oled.setTextSize(2);
  oled.setCursor(0, 12);
  oled.print(voltios, 2);
  oled.print(F(" V"));

  dibujarGrafica();
  oled.display();
}

// Gráfica del histórico de voltaje (escala fija 0..5 V) en la mitad
// inferior. Las muestras nuevas entran por la derecha.
void dibujarGrafica() {
  oled.drawRect(0, GRAF_Y, ANCHO_OLED, GRAF_ALTO, COLOR_OLED);

  // Marca de la mitad de escala (2.5 V): línea punteada
  uint8_t yMitad = GRAF_Y + GRAF_ALTO / 2;
  for (uint8_t x = 2; x < ANCHO_OLED - 2; x += 6) {
    oled.drawPixel(x, yMitad, COLOR_OLED);
  }

  if (nMuestras < 2) {
    return;                          // aún no hay curva que dibujar
  }

  const uint8_t altoUtil = GRAF_ALTO - 2;              // interior del marco
  const uint8_t yBase = GRAF_Y + GRAF_ALTO - 2;        // borde inferior
  // La última muestra cae pegada al borde derecho interior
  int xBase = (ANCHO_OLED - 2) - (nMuestras - 1);

  for (uint8_t i = 1; i < nMuestras; i++) {
    int y1 = yBase - (int)((long)historial[i - 1] * (altoUtil - 1) / 250);
    int y2 = yBase - (int)((long)historial[i] * (altoUtil - 1) / 250);
    oled.drawLine(xBase + i - 1, y1, xBase + i, y2, COLOR_OLED);
  }
}
