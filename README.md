# Plataformas Emergentes (E) — Laboratorios 2026B

Repositorio con los laboratorios del curso **Plataformas Emergentes (E)**, Escuela Profesional de Ingeniería de Sistemas, Universidad Nacional de San Agustín.

**Docente:** MBA Mg. Ing. RENE ALONSO NIETO VALENCIA.
**Integrantes del grupo:**

- Carrasco Choque Arlen Melvin
- Condori Leon Joel Isaias
- Yana Agramonte Luis Efrain 


---

## Índice de laboratorios

| # | Laboratorio | Herramienta | Informe | Estado |
|---|-------------|-------------|---------|--------|
| 1 | [Comparativa de desarrollo de aplicación sin código](./lab1-matricula-laboratorios) | Adalo | [PDF](./lab1-matricula-laboratorios/informe/Laboratorio_Plataformas_Emergentes.pdf) | ✅ Entregado |
| 2 | [Desarrollo Rapido de Aplicaciones Moviles](./LAB02-Plataformas_Emergentes) | Adalo | [PDF](./LAB02-Plataformas_Emergentes/PE_LAB_02%20-%20Carrasco_Condori_Yana..pdf) | ✅ Entregado | 
| 3 | [Desarrollo de aplicaciones móviles web](./LAB03_Desarrollo%20de%20aplicaciones%20móviles%20web) |  | [PDF](./LAB03_Desarrollo%20de%20aplicaciones%20móviles%20web/PE_LAB_03%20-%20Carrasco_Condori_Yana.docx.pdf) | ✅ Entregado |
| 4 | [Framework multiplataforma: MistiVerde](./LAB04-Plataformas_Emergentes/misti_verde) | Flutter | [DOCX](./LAB04-Plataformas_Emergentes/Informe/Informe_Lab04_MistiVerde.docx) | ✅ Entregado |

---

## Estructura del repositorio

```
PE-2026B-labs/
├── README.md                          ← este archivo (índice general)
├── lab1-matricula-laboratorios/
│   ├── informe/
│   │   └── Laboratorio_Plataformas_Emergentes.pdf
│   └── capturas/
│       └── (screenshots del prototipo en Adalo)
├── LAB02-Plataformas_Emergentes/
├── LAB03_Desarrollo de aplicaciones móviles web/
└── LAB04-Plataformas_Emergentes/
    ├── Informe/
    │   └── Informe_Lab04_MistiVerde.docx
    └── misti_verde/                   ← proyecto Flutter (lib/main.dart)
```

Cada carpeta de laboratorio contiene:
- **informe/** → el documento entregado para ese laboratorio.
- **capturas/** → evidencia visual del prototipo (pantallas de la app, editor de la herramienta usada, etc.), cuando aplique.
- Un README propio del laboratorio con el resumen y el enlace al prototipo, cuando aplique.

-----

## Laboratorio 1 — Comparativa de desarrollo de aplicación sin código

**Problema:** Diseñar una aplicación móvil para la matrícula de estudiantes en laboratorios, resolviendo las fallas del sistema actual (saturación en horario pico, falta de cupos en tiempo real, ausencia de lista de espera, entre otras).

**Herramienta seleccionada:** [Adalo](https://www.adalo.com/) — elegida mediante una matriz de decisión ponderada frente a Thunkable, Glide, FlutterFlow y AppSheet.

**Prototipo (Preview de Adalo):** *[pegar aquí el enlace de preview cuando esté listo]*

**Informe completo:** [`lab1-matricula-laboratorios/informe/Laboratorio_Plataformas_Emergentes.pdf`](./lab1-matricula-laboratorios/informe/Laboratorio_Plataformas_Emergentes.pdf)

> **Nota:** el prototipo fue desarrollado bajo el plan gratuito de Adalo con fines de demostración académica. Una implementación productiva real requeriría un plan de pago (Starter o superior) para publicación en tiendas de aplicaciones y remoción de la marca de agua.

-----

## Laboratorio 4 — Framework multiplataforma: MistiVerde

**Problema:** los habitantes de Arequipa tienen dificultad para reciclar correctamente porque no saben cómo clasificar sus residuos, dónde llevarlos ni cuentan con un incentivo para hacerlo de forma constante.

**Solución:** **MistiVerde**, una aplicación multiplataforma desarrollada con **Flutter** (Material Design 3, modo claro y oscuro). Permite:

- Clasificar residuos según el código de colores de tachos de la NTP 900.058:2019.
- Consultar puntos de acopio en lista y en mapa (OpenStreetMap).
- Registrar el reciclaje y ganar "hojas" (10 por kg) que suben el nivel del usuario, de Semilla a Guardián del Misti.
- Completar retos semanales y ver el impacto acumulado con historial.
- Crear un perfil local (onboarding y formulario validado). Los datos se guardan solo en el equipo con `shared_preferences`.

**Paquetes principales:** `shared_preferences`, `flutter_map`, `latlong2`.

**Código fuente:** [`LAB04-Plataformas_Emergentes/misti_verde`](./LAB04-Plataformas_Emergentes/misti_verde) (todo el código está en `lib/main.dart`).

**Informe completo:** [`LAB04-Plataformas_Emergentes/Informe/Informe_Lab04_MistiVerde.docx`](./LAB04-Plataformas_Emergentes/Informe/Informe_Lab04_MistiVerde.docx)

**Cómo ejecutarlo:**

```bash
cd LAB04-Plataformas_Emergentes/misti_verde
flutter pub get
flutter run
```

> **Nota:** es un prototipo académico. El perfil es local (sin autenticación real), los kilogramos son autodeclarados y los puntos de acopio provienen de fuentes públicas sin horarios verificados; deben confirmarse antes de ir. Las teselas del mapa requieren internet.
