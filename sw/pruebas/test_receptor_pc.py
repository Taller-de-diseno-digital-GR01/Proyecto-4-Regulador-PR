# corren sin tarjeta, desde sw con python -m unittest pruebas.test_receptor_pc
import io
import struct
import unittest

import numpy as np

import receptor_pc

FS = 20000 # misma fs que pr_params.h


def armar(registros, offset=2048.0, apc=8.138e-4, escala=1 / 16384, con_signo=1): # igual que exportador_uart.c
    cuerpo = struct.pack("<HIfffB", len(registros), FS, offset, apc, escala, con_signo)
    for cuenta_banderas, duty_ref, i_ref_ma in registros:
        cuerpo += struct.pack("<HHh", cuenta_banderas, duty_ref & 0xFFFF, i_ref_ma) # el & es para meter duty negativo como uint16
    return bytes([0xAA]) + cuerpo + struct.pack("<H", sum(cuerpo) & 0xFFFF) # suma sin el 0xAA


def senoidal(n, amplitud_a, desfase, ref_ma=500):
    registros = []
    for k in range(n):
        fase = 2 * np.pi * 50 * k / FS
        cuenta = round(2048 + amplitud_a * np.sin(fase + desfase) / 8.138e-4) # amperes a cuentas del ADC
        registros.append((cuenta | 1 << 13, 0, round(ref_ma * np.sin(fase)))) # bit 13 = habilitado
    return registros


class LecturaTest(unittest.TestCase):

    def leer(self, datos):
        return receptor_pc.leer_trama(io.BytesIO(datos).read, esperar_inicio=False)

    def test_trama_valida(self):
        trama = armar([(1, 2, 3), (4, 5, 6)])
        self.assertEqual(self.leer(trama), trama)

    def test_bytes_sueltos_antes_del_inicio(self):
        trama = armar([(1, 2, 3)])
        self.assertEqual(self.leer(b"\x13\x37" + trama), trama)

    def test_suma_mala_se_descarta_y_sigue_con_la_proxima(self):
        mala = bytearray(armar([(1, 2, 3)]))
        mala[5] ^= 1 # un bit cambiado en la cabecera
        buena = armar([(7, 8, 9)])
        self.assertEqual(self.leer(bytes(mala) + buena), buena)

    def test_aa_dentro_de_los_registros_no_corta_la_trama(self):
        trama = armar([(0xAAAA, 0xAA, 0xAA)]) # puros 0xAA en los datos
        self.assertEqual(self.leer(trama), trama)

    def test_trama_cortada(self):
        with self.assertRaises(receptor_pc.TramaInvalida):
            self.leer(armar([(1, 2, 3)])[:-1])

    def test_trama_vacia(self):
        self.assertEqual(self.leer(armar([])), armar([]))


class ConversionTest(unittest.TestCase):

    def test_unidades(self):
        banderas = 1 << 15 | 1 << 12 # saturado y falla
        _, m = receptor_pc.desempacar(armar([(2048 + 100 | banderas, -16384, -250), (2048, 8192, 1000)]))
        self.assertAlmostEqual(m["corriente_a"][0], 100 * 8.138e-4, places=6)
        self.assertAlmostEqual(m["corriente_a"][1], 0.0)
        self.assertEqual(list(m["duty"]), [-1.0, 0.5])
        self.assertEqual(list(m["i_ref_a"]), [-0.25, 1.0])
        self.assertEqual(list(m["t_s"]), [0.0, 1 / FS])
        self.assertEqual((m["saturado"][0], m["dato_ausente"][0], m["habilitado"][0], m["falla"][0]), (1, 0, 0, 1))

    def test_duty_sin_signo(self):
        _, m = receptor_pc.desempacar(armar([(0, 0xC000, 0)], con_signo=0))
        self.assertEqual(m["duty"][0], 0xC000 / 16384)


class FundamentalTest(unittest.TestCase):

    def test_amplitud_y_desfase_conocidos(self):
        _, m = receptor_pc.desempacar(armar(senoidal(2048, 0.45, np.radians(-3))))
        r = receptor_pc.analizar(m)
        self.assertEqual(r["periodos"], 5)
        self.assertAlmostEqual(r["error_amplitud_pct"], -10.0, delta=0.2)
        self.assertAlmostEqual(r["desfase_grados"], -3.0, delta=0.1)
        self.assertFalse(r["fuera_de_regimen"])

    def test_frecuencia_que_no_es_multiplo_de_50(self):
        _, m = receptor_pc.desempacar(armar(senoidal(2048, 0.5, 0)))
        m["t_s"] = np.arange(2048) / 19000.0 # 19 kHz no es múltiplo de 50, una DFT acá tendría fuga
        m["corriente_a"] = 0.5 * np.sin(2 * np.pi * 50 * m["t_s"])
        m["i_ref_a"] = m["corriente_a"].copy()
        self.assertAlmostEqual(receptor_pc.analizar(m)["error_amplitud_pct"], 0.0, places=6)

    def test_menos_de_cinco_periodos(self):
        _, m = receptor_pc.desempacar(armar(senoidal(1500, 0.5, 0))) # 1500 a 20 kHz son 3,75 periodos
        with self.assertRaises(ValueError):
            receptor_pc.analizar(m)

    def test_avisa_si_hay_falla_en_la_ventana(self):
        registros = senoidal(2048, 0.5, 0)
        registros[-1] = (registros[-1][0] | 1 << 12, 0, registros[-1][2]) # falla en la última muestra
        _, m = receptor_pc.desempacar(armar(registros))
        self.assertTrue(receptor_pc.analizar(m)["fuera_de_regimen"])


if __name__ == "__main__":
    unittest.main()
