/*
 * uno_boton_led.ino — Arduino UNO
 *
 * Programa para el montaje de la protoboard: un pulsador y un LED.
 * Cada pulsación cambia el modo del LED:
 *   0 = apagado
 *   1 = encendido fijo
 *   2 = parpadeo lento (500 ms)
 *   3 = parpadeo rápido (100 ms)
 *
 * Cableado:
 *   - LED: pata larga (ánodo) -> resistencia 220 Ω -> pin 9
 *          pata corta (cátodo) -> GND
 *   - Pulsador: una pata -> pin 2, la pata diagonal -> GND
 *     (se usa la resistencia pull-up interna, no hace falta externa)
 *
 * Si tu LED o pulsador están en otros pines, cambia solo las dos
 * constantes de abajo.
 */

const uint8_t PIN_LED = 9;     // pin con PWM, por si quieres regular brillo
const uint8_t PIN_BOTON = 2;

const unsigned long DEBOUNCE_MS = 30;

uint8_t modo = 0;                    // 0..3
bool estadoLed = false;
unsigned long ultimoParpadeo = 0;

// Variables para el antirrebote del pulsador
bool lecturaEstable = HIGH;          // HIGH = suelto (pull-up)
bool ultimaLectura = HIGH;
unsigned long ultimoCambio = 0;

void setup() {
  pinMode(PIN_LED, OUTPUT);
  pinMode(PIN_BOTON, INPUT_PULLUP);
  Serial.begin(9600);
  Serial.println(F("Boton + LED listo. Pulsa para cambiar de modo."));
}

void loop() {
  leerBoton();
  actualizarLed();
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
      modo = (modo + 1) % 4;
      Serial.print(F("Modo: "));
      switch (modo) {
        case 0: Serial.println(F("apagado")); break;
        case 1: Serial.println(F("encendido")); break;
        case 2: Serial.println(F("parpadeo lento")); break;
        case 3: Serial.println(F("parpadeo rapido")); break;
      }
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
