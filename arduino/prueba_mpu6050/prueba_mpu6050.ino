/*
 * prueba_mpu6050.ino — Test del acelerómetro MPU-6050 (MEGA, UNO o cualquiera)
 *
 * Herramienta de diagnóstico: despierta el MPU-6050 y muestra la
 * aceleración de los tres ejes por el monitor serie. Sirve para validar
 * el sensor antes de usarlo en mpu_multiusos (alarma, nivel, theremin).
 *
 * Cableado:
 *   VCC -> 5V   GND -> GND   SDA -> pin 20   SCL -> pin 21   (MEGA)
 *                            SDA -> A4       SCL -> A5       (UNO)
 *   (XDA, XCL, AD0 e INT: sin conectar)
 *
 * Uso:
 *   1. Sube el sketch y abre el Monitor Serie a 9600 baudios.
 *   2. Interpreta los valores (están en g, la aceleración de la gravedad):
 *        - Plano sobre la mesa:  X: 0.00  Y: 0.00  Z: 1.00  (±0.05 normal)
 *          Ese Z=1 es la gravedad: buena señal.
 *        - Al inclinarlo, el 1.00 se "muda" de Z hacia X o Y.
 *        - Boca abajo: Z: -1.00.
 *        - Al agitarlo, los números se disparan un instante.
 *   3. Si dice "MPU no responde" o los valores no cambian al moverlo:
 *      cables SDA/SCL cruzados, mal contacto o pines sin soldar.
 *      (Puedes confirmar la conexión con escaner_i2c: debe salir 0x68.)
 *
 * No necesita ninguna librería externa.
 */

#include <Wire.h>

const uint8_t DIR_MPU = 0x68;    // dirección I2C (0x69 si AD0 va a 5V)
bool conectado = false;

bool despertarMpu() {
  Wire.beginTransmission(DIR_MPU);
  Wire.write(0x6B);              // registro PWR_MGMT_1
  Wire.write(0);                 // salir del modo de bajo consumo
  return Wire.endTransmission() == 0;
}

void setup() {
  Wire.begin();
  Serial.begin(9600);

  conectado = despertarMpu();
  if (conectado) {
    Serial.println(F("MPU-6050 despierto. Inclina el sensor y observa:"));
  } else {
    Serial.println(F("MPU no responde en 0x68. Revisa VCC/GND/SDA/SCL y "
                     "las soldaduras de los pines."));
  }
}

void loop() {
  if (!conectado) {
    conectado = despertarMpu();  // reintenta por si arreglan el cable
    delay(1000);
    return;
  }

  Wire.beginTransmission(DIR_MPU);
  Wire.write(0x3B);              // primer registro del acelerómetro
  if (Wire.endTransmission(false) != 0 ||
      Wire.requestFrom(DIR_MPU, (uint8_t)6) != 6) {
    Serial.println(F("Se perdió la comunicación con el MPU."));
    conectado = false;
    return;
  }

  int16_t x = (Wire.read() << 8) | Wire.read();
  int16_t y = (Wire.read() << 8) | Wire.read();
  int16_t z = (Wire.read() << 8) | Wire.read();

  Serial.print(F("X: "));
  Serial.print(x / 16384.0, 2);
  Serial.print(F("  Y: "));
  Serial.print(y / 16384.0, 2);
  Serial.print(F("  Z: "));
  Serial.println(z / 16384.0, 2);

  delay(300);
}
