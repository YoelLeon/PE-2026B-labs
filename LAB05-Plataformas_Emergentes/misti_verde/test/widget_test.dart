import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:misti_verde/main.dart';

void main() {
  test('Registro se guarda y se lee como texto', () {
    final r = Registro('Vidrio', 2.5, 25, DateTime(2026, 10, 18));
    final leido = Registro.desdeTexto(r.aTexto());
    expect(leido?.categoria, 'Vidrio');
    expect(leido?.puntos, 25);
  });

  test('El tema elegido se guarda en el equipo', () async {
    SharedPreferences.setMockInitialValues({});
    await guardarTema(ThemeMode.dark);
    modoTema.value = ThemeMode.system;
    await cargarTema();
    expect(modoTema.value, ThemeMode.dark);
  });
}
