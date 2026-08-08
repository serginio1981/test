/*
 * mpu_multiusos.ino — Arduino MEGA 2560
 *
 * Tres proyectos en un solo sketch, usando el MPU-6050 (acelerómetro),
 * el buzzer pasivo, el encoder rotativo y la OLED (opcional):
 *
 *   MODO 0 — ALARMA 🚨   Vigila el movimiento. Pulsa el encoder para
 *            armarla: pita 3 segundos (tiempo de escape), memoriza la
 *            posición y, si alguien mueve el montaje, suena la sirena.
 *            Otra pulsación la desarma.
 *   MODO 1 — NIVEL 🫧    Nivel de burbuja digital: la burbuja se mueve en
 *            la pantalla según inclines el sensor. Pulsar = calibrar el
 *            cero (ponlo sobre una superficie plana y pulsa).
 *   MODO 2 — THEREMIN 🎵 El tono del buzzer cambia con la inclinación del
 *            sensor. Pulsar = silenciar/activar.
 *
 * GIRAR el encoder cambia de modo. La OLED muestra el modo actual; si no
 * hay pantalla el sketch sigue funcionando y lo cuenta por el monitor
 * serie (9600 baudios).
 *
 * Comandos serie (para usarlo SIN encoder, desde la CLI o el monitor):
 *   M0 / M1 / M2 -> cambia a ese modo (alarma / nivel / theremin)
 *   P            -> equivale a pulsar el boton del encoder
 *   ?            -> reenvia el modo actual
 * Cuando la alarma se dispara publica "EVENTO:ALARMA" cada 3 s — la CLI
 * del PC lo reconoce y hace sonar la alarma en el ordenador.
 *
 * Cableado (MEGA 2560):
 *   MPU-6050 (I2C, convive con la OLED en el mismo bus):
 *     VCC -> 5V   GND -> GND   SDA -> pin 20   SCL -> pin 21
 *     (XDA, XCL, AD0, INT sin conectar)
 *   Buzzer pasivo (opcional):
 *     S -> pin 8      - -> GND     (pin central: sin conectar)
 *   LED "sirena visual" (opcional, para cuando no hay buzzer o esta roto):
 *     anodo (pata larga) -> resistencia 220 ohm -> pin 9
 *     catodo (pata corta) -> GND
 *     Alarma: parpadeo rapido al dispararse y destello de vigilancia.
 *     Nivel: LED fijo cuando esta nivelado (+-2 grados).
 *     Theremin: el brillo sigue la inclinacion.
 *   Encoder EC11:
 *     lado de 3 pines: A -> pin 2, C (centro) -> GND, B -> pin 3
 *     lado de 2 pines: uno -> pin 4, el otro -> GND
 *   OLED (opcional): VDD -> 5V, GND -> GND, SDA -> 20, SCK -> 21
 *
 * El MPU-6050 se lee directamente por I2C: NO necesita librería propia.
 * Librerías de pantalla: Adafruit GFX + Adafruit SH110X (o Adafruit
 * SSD1306 si comentas PANTALLA_SH1106).
 */

#include <Wire.h>
#include <Adafruit_GFX.h>
// --- Elige el chip de tu pantalla OLED ---
#define PANTALLA_SH1106

#ifdef PANTALLA_SH1106
#include <Adafruit_SH110X.h>
#else
#include <Adafruit_SSD1306.h>
#endif

// --- Pines ---
const uint8_t PIN_ENCODER_CLK = 2;
const uint8_t PIN_ENCODER_DT  = 3;
const uint8_t PIN_ENCODER_SW  = 4;
const uint8_t PIN_BUZZER      = 8;
const uint8_t PIN_LED         = 9;   // LED con resistencia de 220 ohm (opcional)

// --- Pantalla ---
const uint8_t ANCHO_OLED = 128;
const uint8_t ALTO_OLED  = 64;
#ifdef PANTALLA_SH1106
Adafruit_SH1106G oled(ANCHO_OLED, ALTO_OLED, &Wire, -1);
#define COLOR_OLED SH110X_WHITE
#define COLOR_NEGRO SH110X_BLACK
#else
Adafruit_SSD1306 oled(ANCHO_OLED, ALTO_OLED, &Wire, -1);
#define COLOR_OLED SSD1306_WHITE
#define COLOR_NEGRO SSD1306_BLACK
#endif

bool iniciarOled() {
#ifdef PANTALLA_SH1106
  return oled.begin(0x3C, true);
#else
  return oled.begin(SSD1306_SWITCHCAPVCC, 0x3C);
#endif
}

// --- MPU-6050 por I2C directo ---
const uint8_t DIR_MPU = 0x68;
bool hayMpu = false;
bool hayOled = false;

// --- Modos ---
const uint8_t N_MODOS = 3;
const char* NOMBRE_MODO[N_MODOS] = {"ALARMA", "NIVEL", "THEREMIN"};
volatile int8_t giroPendiente = 0;   // lo alimenta la interrupción
uint8_t modo = 0;

// --- Estado de la alarma ---
enum EstadoAlarma { DESARMADA, ARMANDO, VIGILANDO, DISPARADA };
EstadoAlarma alarma = DESARMADA;
unsigned long inicioArmado = 0;
float baseX, baseY, baseZ;           // posición memorizada al armar
unsigned long ultimoEvento = 0;      // último "EVENTO:ALARMA" enviado
const float UMBRAL_ALARMA = 0.18;    // en g; súbelo si salta sola

// --- Nivel ---
float ceroPitch = 0, ceroRoll = 0;   // calibración del cero

// --- Theremin ---
bool silenciado = false;

// --- Botón del encoder (antirrebote) ---
bool lecturaEstable = HIGH, ultimaLectura = HIGH;
unsigned long ultimoCambioBoton = 0;
const unsigned long DEBOUNCE_MS = 40;

unsigned long ultimoRefresco = 0;
const unsigned long REFRESCO_MS = 100;

void setup() {
  Serial.begin(9600);
  Wire.begin();

  pinMode(PIN_ENCODER_CLK, INPUT_PULLUP);
  pinMode(PIN_ENCODER_DT, INPUT_PULLUP);
  pinMode(PIN_ENCODER_SW, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED, OUTPUT);
  attachInterrupt(digitalPinToInterrupt(PIN_ENCODER_CLK), leerEncoder, FALLING);

  hayOled = iniciarOled();
  if (!hayOled) {
    Serial.println(F("Aviso: sin OLED (el sketch sigue por el monitor serie)."));
  }

  hayMpu = despertarMpu();
  if (!hayMpu) {
    Serial.println(F("Aviso: no responde el MPU-6050 en 0x68. Revisa "
                     "VCC/GND/SDA(20)/SCL(21) y las soldaduras de los pines."));
  }

  Serial.println(F("Multiusos listo. Gira el encoder: cambia de modo. "
                   "Pulsa: accion del modo."));
  anunciarModo();
  pitido(880, 80);                   // saludo
}

void loop() {
  atenderGiro();
  atenderBoton();
  leerSerie();

  switch (modo) {
    case 0: correrAlarma(); break;
    case 1: correrNivel(); break;
    case 2: correrTheremin(); break;
  }

  if (millis() - ultimoRefresco >= REFRESCO_MS) {
    ultimoRefresco = millis();
    dibujarPantalla();
  }
}

// ------------------------------------------------------------ encoder
void leerEncoder() {
  giroPendiente += (digitalRead(PIN_ENCODER_DT) == HIGH) ? 1 : -1;
}

void atenderGiro() {
  if (giroPendiente == 0) {
    return;
  }
  noInterrupts();
  int8_t giro = giroPendiente;
  giroPendiente = 0;
  interrupts();

  cambiarModo((modo + N_MODOS + (giro > 0 ? 1 : N_MODOS - 1)) % N_MODOS);
}

void cambiarModo(uint8_t nuevo) {
  modo = nuevo % N_MODOS;
  noTone(PIN_BUZZER);                // corta lo que sonara del modo anterior
  digitalWrite(PIN_LED, LOW);
  alarma = DESARMADA;                // cambiar de modo desarma por seguridad
  anunciarModo();
  pitido(440 + 220 * modo, 60);      // tono distinto por modo
}

// Comandos desde la CLI del PC (o el monitor serie): permiten manejar
// los modos sin tener el encoder conectado.
void leerSerie() {
  while (Serial.available() > 0) {
    char c = Serial.read();
    if (c == 'M' || c == 'm') {
      unsigned long inicio = millis();
      while (Serial.available() == 0 && millis() - inicio < 50) {}
      if (Serial.available() > 0) {
        char d = Serial.read();
        if (d >= '0' && d < '0' + N_MODOS) {
          cambiarModo(d - '0');
        }
      }
    } else if (c == 'P' || c == 'p') {
      accionDelModo();               // como pulsar el boton del encoder
    } else if (c == '?') {
      anunciarModo();
    }
  }
}

void anunciarModo() {
  Serial.print(F("MODO:"));
  Serial.print(modo);
  Serial.print(' ');
  Serial.println(NOMBRE_MODO[modo]);
}

void atenderBoton() {
  bool lectura = digitalRead(PIN_ENCODER_SW);
  if (lectura != ultimaLectura) {
    ultimoCambioBoton = millis();
    ultimaLectura = lectura;
  }
  if (millis() - ultimoCambioBoton > DEBOUNCE_MS && lectura != lecturaEstable) {
    lecturaEstable = lectura;
    if (lecturaEstable == LOW) {
      accionDelModo();
    }
  }
}

void accionDelModo() {
  switch (modo) {
    case 0:                          // alarma: armar / desarmar
      if (alarma == DESARMADA) {
        alarma = ARMANDO;
        inicioArmado = millis();
        Serial.println(F("ALARMA: armando (3 s para retirarte)..."));
      } else {
        alarma = DESARMADA;
        noTone(PIN_BUZZER);
        digitalWrite(PIN_LED, LOW);
        Serial.println(F("ALARMA: desarmada."));
        pitido(600, 100);
      }
      break;
    case 1:                          // nivel: calibrar el cero
      if (hayMpu) {
        float p, r;
        leerInclinacion(p, r);
        ceroPitch = p;
        ceroRoll = r;
        Serial.println(F("NIVEL: cero calibrado."));
        pitido(1000, 60);
      }
      break;
    case 2:                          // theremin: silenciar
      silenciado = !silenciado;
      if (silenciado) {
        noTone(PIN_BUZZER);
      }
      Serial.println(silenciado ? F("THEREMIN: silencio.")
                                : F("THEREMIN: sonando."));
      break;
  }
}

// ---------------------------------------------------------------- MPU
bool despertarMpu() {
  Wire.beginTransmission(DIR_MPU);
  Wire.write(0x6B);                  // registro PWR_MGMT_1
  Wire.write(0);                     // despertar (sale del modo sleep)
  return Wire.endTransmission() == 0;
}

// Aceleración en g (la gravedad marca quién está "abajo")
bool leerAcelG(float& ax, float& ay, float& az) {
  Wire.beginTransmission(DIR_MPU);
  Wire.write(0x3B);                  // primer registro del acelerómetro
  if (Wire.endTransmission(false) != 0) {
    return false;
  }
  if (Wire.requestFrom(DIR_MPU, (uint8_t)6) != 6) {
    return false;
  }
  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();
  ax = x / 16384.0;
  ay = y / 16384.0;
  az = z / 16384.0;
  return true;
}

// Inclinación en grados a partir de la gravedad
void leerInclinacion(float& pitch, float& roll) {
  float ax, ay, az;
  if (!leerAcelG(ax, ay, az)) {
    pitch = roll = 0;
    return;
  }
  pitch = atan2(ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
  roll  = atan2(ay, sqrt(ax * ax + az * az)) * 180.0 / PI;
}

// --------------------------------------------------------------- nivel
void correrNivel() {
  if (!hayMpu) {
    return;
  }
  float pitch, roll;
  leerInclinacion(pitch, roll);
  bool nivelado = fabs(pitch - ceroPitch) < 2 && fabs(roll - ceroRoll) < 2;
  digitalWrite(PIN_LED, nivelado);   // LED fijo = superficie nivelada
}

// -------------------------------------------------------------- alarma
void correrAlarma() {
  if (!hayMpu || alarma == DESARMADA) {
    return;
  }

  if (alarma == ARMANDO) {
    // pitidos de cuenta atrás y, a los 3 s, memorizar la posición
    if ((millis() - inicioArmado) % 1000 < 60) {
      tone(PIN_BUZZER, 700, 50);
    }
    digitalWrite(PIN_LED, (millis() - inicioArmado) % 500 < 250);
    if (millis() - inicioArmado >= 3000) {
      leerAcelG(baseX, baseY, baseZ);
      alarma = VIGILANDO;
      Serial.println(F("ALARMA: vigilando."));
      pitido(1200, 150);
    }
    return;
  }

  if (alarma == VIGILANDO) {
    // destello corto cada 2 s: "estoy vigilando"
    digitalWrite(PIN_LED, millis() % 2000 < 60);
    float ax, ay, az;
    if (!leerAcelG(ax, ay, az)) {
      return;
    }
    float delta = fabs(ax - baseX) + fabs(ay - baseY) + fabs(az - baseZ);
    if (delta > UMBRAL_ALARMA) {
      alarma = DISPARADA;
      ultimoEvento = 0;              // publica el evento inmediatamente
      Serial.println(F("ALARMA: MOVIMIENTO DETECTADO!"));
    }
    return;
  }

  // DISPARADA: sirena de dos tonos (si hay buzzer), LED a destellos
  // rapidos (sirena visual) y evento serie cada 3 s para que el PC
  // tambien suene, hasta que pulsen el boton (o llegue una P)
  if (millis() - ultimoEvento >= 3000) {
    ultimoEvento = millis();
    Serial.println(F("EVENTO:ALARMA"));
  }
  tone(PIN_BUZZER, (millis() % 300 < 150) ? 800 : 1200);
  digitalWrite(PIN_LED, millis() % 160 < 80);
}

// ------------------------------------------------------------ theremin
void correrTheremin() {
  if (!hayMpu || silenciado) {
    analogWrite(PIN_LED, 0);
    return;
  }
  float pitch, roll;
  leerInclinacion(pitch, roll);
  // -60..60 grados -> 200..1800 Hz
  int frecuencia = map((int)constrain(pitch, -60, 60), -60, 60, 200, 1800);
  tone(PIN_BUZZER, frecuencia);
  // sin buzzer tambien se "ve" la nota: el brillo del LED sigue el tono
  analogWrite(PIN_LED, map(frecuencia, 200, 1800, 5, 255));
}

void pitido(int frecuencia, int ms) {
  tone(PIN_BUZZER, frecuencia, ms);
}

// ------------------------------------------------------------ pantalla
void dibujarPantalla() {
  if (!hayOled) {
    // Sin pantalla: en modo nivel, contar la inclinación por el serie
    static unsigned long ultimoTexto = 0;
    if (modo == 1 && hayMpu && millis() - ultimoTexto > 1000) {
      ultimoTexto = millis();
      float p, r;
      leerInclinacion(p, r);
      Serial.print(F("NIVEL pitch:"));
      Serial.print(p - ceroPitch, 1);
      Serial.print(F(" roll:"));
      Serial.println(r - ceroRoll, 1);
    }
    return;
  }

  oled.clearDisplay();
  oled.setTextColor(COLOR_OLED);
  oled.setTextSize(1);
  oled.setCursor(0, 0);
  oled.print(F("Modo: "));
  oled.println(NOMBRE_MODO[modo]);

  if (!hayMpu) {
    oled.setCursor(0, 24);
    oled.println(F("Sin MPU-6050 (0x68)"));
    oled.println(F("Revisa cables/pines"));
    oled.display();
    return;
  }

  switch (modo) {
    case 0: pantallaAlarma(); break;
    case 1: pantallaNivel(); break;
    case 2: pantallaTheremin(); break;
  }
  oled.display();
}

void pantallaAlarma() {
  oled.setTextSize(2);
  oled.setCursor(0, 24);
  switch (alarma) {
    case DESARMADA: oled.print(F("Desarmada")); break;
    case ARMANDO:   oled.print(F("Armando "));
                    oled.print(3 - (millis() - inicioArmado) / 1000); break;
    case VIGILANDO: oled.print(F("Vigilando")); break;
    case DISPARADA:
      // parpadeo invertido para que llame la atencion
      if (millis() % 400 < 200) {
        oled.fillRect(0, 16, ANCHO_OLED, 48, COLOR_OLED);
        oled.setTextColor(COLOR_NEGRO);
      }
      oled.setCursor(10, 30);
      oled.print(F("ALARMA!"));
      oled.setTextColor(COLOR_OLED);
      break;
  }
  oled.setTextSize(1);
  oled.setCursor(0, 56);
  oled.print(F("Pulsa: armar/desarmar"));
}

void pantallaNivel() {
  float pitch, roll;
  leerInclinacion(pitch, roll);
  pitch -= ceroPitch;
  roll -= ceroRoll;

  // Diana centrada con la burbuja; +-30 grados llegan al borde
  const int cx = 64, cy = 38, radio = 24;
  oled.drawCircle(cx, cy, radio, COLOR_OLED);
  oled.drawCircle(cx, cy, radio / 2, COLOR_OLED);
  oled.drawFastHLine(cx - radio, cy, radio * 2, COLOR_OLED);
  oled.drawFastVLine(cx, cy - radio, radio * 2, COLOR_OLED);

  int bx = cx + constrain(roll, -30, 30) * radio / 30;
  int by = cy + constrain(pitch, -30, 30) * radio / 30;
  oled.fillCircle(bx, by, 4, COLOR_OLED);

  oled.setCursor(0, 12);
  oled.print(roll, 0);
  oled.print((char)247);
  oled.setCursor(100, 12);
  oled.print(pitch, 0);
  oled.print((char)247);
}

void pantallaTheremin() {
  float pitch, roll;
  leerInclinacion(pitch, roll);
  int frecuencia = map((int)constrain(pitch, -60, 60), -60, 60, 200, 1800);

  oled.setTextSize(2);
  oled.setCursor(0, 22);
  if (silenciado) {
    oled.print(F("Silencio"));
  } else {
    oled.print(frecuencia);
    oled.print(F(" Hz"));
  }

  // Barra de frecuencia
  int ancho = map(frecuencia, 200, 1800, 0, ANCHO_OLED);
  oled.drawRect(0, 46, ANCHO_OLED, 10, COLOR_OLED);
  oled.fillRect(0, 46, ancho, 10, COLOR_OLED);

  oled.setTextSize(1);
  oled.setCursor(0, 57);
  oled.print(F("Inclina para tocar"));
}
