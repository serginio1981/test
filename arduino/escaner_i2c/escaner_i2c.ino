/*
 * escaner_i2c.ino — Escáner del bus I2C (MEGA 2560, UNO o cualquier Arduino)
 *
 * Herramienta de diagnóstico: recorre todas las direcciones I2C y dice en
 * cuáles responde un dispositivo. Úsala cuando una pantalla OLED (u otro
 * módulo I2C) no arranca, para saber si el problema es el cableado o la
 * dirección.
 *
 * Uso:
 *   1. Sube este sketch (misma placa y puerto de siempre).
 *   2. Abre el Monitor Serie a 9600 baudios (o mira la salida por la CLI).
 *   3. Interpreta el resultado:
 *        - "Dispositivo en 0x3C" -> cableado bien; es la dirección típica
 *          de las OLED. Si tu sketch ya usa 0x3C y aun así no pinta nada,
 *          el chip de la pantalla puede ser SH1106/SSD1309 (necesita otra
 *          librería).
 *        - "Dispositivo en 0x3D" -> cambia 0x3C por 0x3D en el sketch de
 *          la pantalla y resube.
 *        - "Ninguno" -> problema de cableado: SDA/SCL cruzados, cable
 *          suelto o sin alimentación.
 *
 * Conexión de la OLED en el MEGA:  VDD->5V  GND->GND  SCK->21  SDA->20
 * (en el UNO: SCK->A5, SDA->A4)
 *
 * No necesita ninguna librería externa.
 */

#include <Wire.h>

void setup() {
  Wire.begin();
  Serial.begin(9600);
}

void loop() {
  byte encontrados = 0;

  Serial.println(F("Escaneando bus I2C..."));
  for (byte direccion = 8; direccion < 120; direccion++) {
    Wire.beginTransmission(direccion);
    byte resultado = Wire.endTransmission();
    if (resultado == 0) {
      Serial.print(F("  Dispositivo en 0x"));
      if (direccion < 16) {
        Serial.print('0');
      }
      Serial.println(direccion, HEX);
      encontrados++;
    }
  }

  if (encontrados == 0) {
    Serial.println(F("  Ninguno. Revisa el cableado (¿SDA y SCL cruzados?)."));
  } else {
    Serial.print(F("  Total: "));
    Serial.println(encontrados);
  }
  Serial.println(F("Nuevo escaneo en 3 segundos...\n"));
  delay(3000);
}
