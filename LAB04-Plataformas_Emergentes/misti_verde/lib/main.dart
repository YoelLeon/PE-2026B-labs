import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        FlutterMap,
        MapOptions,
        TileLayer,
        MarkerLayer,
        Marker,
        RichAttributionWidget,
        TextSourceAttribution;
// 'show LatLng' evita un choque de nombres: latlong2 tambien define 'Path'
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// MistiVerde - App multiplataforma para reciclaje en Arequipa (Flutter)
//
// HISTORIAL DE CAMBIOS (se marcan como comentarios, segun la guia):
//  [v1] App inicial "EcoArequipa" (4 pantallas, datos de ejemplo).
//  [v2] Nombre MistiVerde, hojas, niveles, splash, ilustracion Misti,
//       categorias interactivas, detalle de punto, retos, tema y modo oscuro.
//  [v3-1] Fotos reales (assets/images/) con ilustracion de respaldo.
//  [v4-1] Colores de tachos segun NTP 900.058:2019 (ambito municipal).
//  [v4-2] Nuevas categorias: Peligrosos y No aprovechable. Mas residuos.
//  [v4-3] Persistencia local con shared_preferences (no se pierden datos).
//  [v4-4] Retos realmente semanales (cada registro guarda su fecha).
//  [v4-5] Puntos de acopio con datos de fuentes publicas (sin datos inventados).
//  [v4-6] Layout: ancho maximo, LayoutBuilder, AspectRatio, Table, Spacer, Flexible.
//  [v4-7] Clasificador con filtro por categoria y resumen por categoria en Impacto.
//  [v5-A] Perfil local: onboarding (PageView), formulario validado (Form),
//         Drawer con perfil, editar perfil y cerrar sesion. No es autenticacion.
//  [v5-B] Mapa real (flutter_map + OpenStreetMap) en Puntos con TabBar Lista | Mapa.
//  [v5-C] CustomScrollView/SliverAppBar en categoria, Dismissible en historial,
//         MediaQuery en Inicio y fuentes de puntos de acopio corregidas.
// =====================================================================

void main() => runApp(const MistiVerdeApp());

// ---------------------------------------------------------------
// PALETA DE COLORES TEMATICA
// ---------------------------------------------------------------
const verdeMisti = Color(0xFF2E7D32);
const verdeOscuro = Color(0xFF1B5E20);
const sillar = Color(0xFFF7F4EC); // blanco "sillar", piedra de la Ciudad Blanca

// ---------------------------------------------------------------
// MODELOS DE DATOS
// ---------------------------------------------------------------
class Categoria {
  final String nombre;
  final IconData icono;
  final MaterialColor color;
  final String foto; // archivo en assets/images/
  final bool reciclable; // false: no se puede registrar como reciclaje
  const Categoria(this.nombre, this.icono, this.color, this.foto,
      {this.reciclable = true});
}

// [v4-1] Contenedor segun el codigo de colores de la NTP 900.058:2019
class Contenedor {
  final String nombre;
  final Color color;
  const Contenedor(this.nombre, this.color);
}

const tachoVerde = Contenedor('Tacho verde (aprovechables)', Colors.green);
const tachoMarron = Contenedor('Tacho marrón (orgánicos)', Colors.brown);
const tachoRojo = Contenedor('Tacho rojo (peligrosos)', Colors.red);
const tachoNegro = Contenedor('Tacho negro (no aprovechables)', Colors.black87);
const puntoEspecial =
    Contenedor('Punto de acopio especial (no va al tacho)', Colors.purple);

class Residuo {
  final String nombre;
  final String categoria;
  final Contenedor contenedor;
  final String instruccion;
  const Residuo(this.nombre, this.categoria, this.contenedor, this.instruccion);
}

// [v4-5] Punto de acopio con la fuente de donde se obtuvo el dato
class PuntoAcopio {
  final String nombre;
  final String ubicacion;
  final List<String> acepta;
  final String detalle;
  final String fuente;
  // [v5-B] Posicion para el mapa (null = sin ubicacion verificada)
  final double? lat;
  final double? lng;
  final String? precision; // aclara que tan exacta es la posicion
  const PuntoAcopio(
      this.nombre, this.ubicacion, this.acepta, this.detalle, this.fuente,
      {this.lat, this.lng, this.precision});

  bool get tieneMapa => lat != null && lng != null;
}

// [v4-3] Registro con fecha y conversion a texto para guardarlo en el equipo
class Registro {
  final String categoria;
  final double kg;
  final int puntos;
  final DateTime fecha;
  const Registro(this.categoria, this.kg, this.puntos, this.fecha);

  String aTexto() => '$categoria|$kg|$puntos|${fecha.toIso8601String()}';

  static Registro? desdeTexto(String s) {
    final p = s.split('|');
    if (p.length != 4) return null;
    final kg = double.tryParse(p[1]);
    final pts = int.tryParse(p[2]);
    final f = DateTime.tryParse(p[3]);
    if (kg == null || pts == null || f == null) return null;
    return Registro(p[0], kg, pts, f);
  }
}

// [v5-A] Perfil local. Se guarda solo en el equipo (shared_preferences).
// NO es autenticacion: no hay contrasena ni servidor.
class Perfil {
  final String nombre;
  final String alias;
  final String distrito;
  const Perfil(this.nombre, this.alias, this.distrito);

  static const _kNombre = 'perfil_nombre';
  static const _kAlias = 'perfil_alias';
  static const _kDistrito = 'perfil_distrito';

  static Future<Perfil?> cargar() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString(_kNombre);
    final a = p.getString(_kAlias);
    final d = p.getString(_kDistrito);
    if (n == null || a == null || d == null) return null;
    return Perfil(n, a, d);
  }

  Future<void> guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kNombre, nombre);
    await p.setString(_kAlias, alias);
    await p.setString(_kDistrito, distrito);
  }

  static Future<void> borrar() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kNombre);
    await p.remove(_kAlias);
    await p.remove(_kDistrito);
  }
}

class Reto {
  final String titulo;
  final String? categoria; // null = cuenta todo el reciclaje
  final double metaKg;
  const Reto(this.titulo, this.categoria, this.metaKg);
}

const categorias = [
  Categoria('Plástico', Icons.local_drink, Colors.blue, 'cat_plastico.jpg'),
  Categoria('Papel y cartón', Icons.description, Colors.orange, 'cat_papel.jpg'),
  Categoria('Vidrio', Icons.wine_bar, Colors.green, 'cat_vidrio.jpg'),
  Categoria('Metal', Icons.build, Colors.blueGrey, 'cat_metal.jpg'),
  Categoria('Orgánico', Icons.eco, Colors.brown, 'cat_organico.jpg'),
  Categoria('Electrónicos', Icons.devices, Colors.purple, 'cat_electronicos.jpg'),
  Categoria('Peligrosos', Icons.warning_amber, Colors.red, 'cat_peligrosos.jpg',
      reciclable: false),
  Categoria('No aprovechable', Icons.delete, Colors.grey, 'cat_noaprovechable.jpg',
      reciclable: false),
];

const residuos = [
  // Plastico
  Residuo('Botella de agua', 'Plástico', tachoVerde,
      'Vacíala, aplástala y ponle la tapa.'),
  Residuo('Bolsa plástica', 'Plástico', tachoVerde,
      'Debe estar limpia y seca.'),
  Residuo('Envase de shampoo o detergente', 'Plástico', tachoVerde,
      'Enjuágalo antes de desecharlo.'),
  // Papel y carton
  Residuo('Caja de cartón', 'Papel y cartón', tachoVerde,
      'Desármala y mantenla seca.'),
  Residuo('Periódico y revistas', 'Papel y cartón', tachoVerde,
      'No lo mezcles con papel mojado o grasoso.'),
  Residuo('Cuadernos y hojas usadas', 'Papel y cartón', tachoVerde,
      'Retira las espirales o los forros plásticos.'),
  Residuo('Caja de leche o jugo', 'Papel y cartón', tachoVerde,
      'Es un empaque compuesto: enjuágala y aplánala.'),
  // Vidrio
  Residuo('Frasco de vidrio', 'Vidrio', tachoVerde,
      'Enjuágalo y retira la tapa metálica.'),
  Residuo('Botella de vidrio', 'Vidrio', tachoVerde,
      'Vacíala y enjuágala. Colócala con cuidado.'),
  // Metal
  Residuo('Lata de atún o conservas', 'Metal', tachoVerde,
      'Enjuágala y aplástala si puedes.'),
  Residuo('Lata de gaseosa', 'Metal', tachoVerde, 'Vacíala y aplástala.'),
  // Organico
  Residuo('Cáscaras de fruta y verdura', 'Orgánico', tachoMarron,
      'También sirven para compost casero.'),
  Residuo('Restos de comida', 'Orgánico', tachoMarron,
      'Sepáralos de envolturas y bolsas plásticas.'),
  Residuo('Hojarasca y restos de poda', 'Orgánico', tachoMarron,
      'Ideal para hacer compost.'),
  // Peligrosos
  Residuo('Pilas usadas', 'Peligrosos', tachoRojo,
      'Nunca a la basura común. Guárdalas aparte en un envase cerrado.'),
  Residuo('Focos y lámparas ahorradoras', 'Peligrosos', tachoRojo,
      'Manéjalas con cuidado para no romperlas.'),
  Residuo('Medicinas vencidas', 'Peligrosos', tachoRojo,
      'No las botes al desagüe ni al tacho común.'),
  Residuo('Envases de plaguicidas', 'Peligrosos', tachoRojo,
      'Ciérralos bien y manténlos lejos de niños y mascotas.'),
  // No aprovechables
  Residuo('Papel higiénico y pañales', 'No aprovechable', tachoNegro,
      'Residuos sanitarios: van en bolsa cerrada.'),
  Residuo('Colillas de cigarro', 'No aprovechable', tachoNegro,
      'Apágalas del todo antes de botarlas.'),
  Residuo('Papel encerado o metalizado', 'No aprovechable', tachoNegro,
      'Parece papel, pero no se recicla.'),
  Residuo('Platos y tazas rotos (cerámica)', 'No aprovechable', tachoNegro,
      'Envuélvelos para evitar cortes.'),
  // Electronicos
  Residuo('Celular viejo', 'Electrónicos', puntoEspecial,
      'Llévalo a un punto de acopio de residuos electrónicos (pestaña Puntos).'),
  Residuo('Cargadores y cables', 'Electrónicos', puntoEspecial,
      'Júntalos y llévalos a un punto de acopio.'),
  Residuo('Computadora o laptop vieja', 'Electrónicos', puntoEspecial,
      'No la botes: contiene materiales contaminantes y reutilizables.'),
];

// [v4-5] Datos tomados de fuentes publicas. NO incluyen horarios porque no se
// pudieron verificar. Se debe confirmar la vigencia antes de ir.
const puntos = [
  PuntoAcopio(
    'Vivero municipal de Cerro Colorado',
    'Distrito de Cerro Colorado (dirección exacta por confirmar)',
    ['Electrónicos'],
    'Punto permanente de acopio de residuos eléctricos y electrónicos. A cambio de los equipos se entregan plantas.',
    'Diario Correo Arequipa (campaña RAEE de Recolet y la Municipalidad de Arequipa, 2023)',
    // [v5-B] Referencia: centro del distrito (Wikipedia). No es la direccion exacta.
    lat: -16.3768,
    lng: -71.5603,
    precision:
        'Referencia aproximada: centro del distrito de Cerro Colorado. No es la dirección exacta.',
  ),
  PuntoAcopio(
    'Asociación Artempa',
    'Carretera Vía Evitamiento, km 34',
    ['Electrónicos'],
    'Figura como punto público de acopio de residuos electrónicos.',
    'Recolecc (listado de puntos de acopio públicos; página con varios años de antigüedad)',
  ),
  PuntoAcopio(
    'Planta de Residuos Sólidos (Yanahuara)',
    'Km 18 de la carretera a Yura',
    ['Electrónicos'],
    'Figura bajo la Municipalidad Distrital de Yanahuara como punto de acopio de residuos electrónicos.',
    'Recolecc (listado de puntos de acopio públicos; página con varios años de antigüedad)',
  ),
  PuntoAcopio(
    'Servicios Electrónicos La Recoleta E.I.R.L.',
    'Arequipa (ubicación en el mapa de Recolecc)',
    ['Electrónicos'],
    'Figura como punto público de acopio de residuos electrónicos.',
    'Recolecc (listado de puntos de acopio públicos)',
  ),
  PuntoAcopio(
    'SIDERPERÚ - Centro de Reciclaje de Chatarra',
    'Distrito de Yura (Asociación de Granjeros y Pequeños Industriales Bellavista)',
    ['Metal'],
    'Recibe y procesa chatarra, incluida la de origen doméstico. Está orientado a recicladores y proveedores: confirma si atiende al público.',
    'Energiminas (inauguración, octubre de 2024) y Revista Economía (ubicación en la Asociación Bellavista, Yura)',
    // [v5-B] Referencia: centro del distrito (Wikipedia). No es la direccion exacta.
    lat: -16.25111,
    lng: -71.68111,
    precision:
        'Referencia aproximada: centro del distrito de Yura. No es la dirección exacta.',
  ),
];

const retos = [
  Reto('Recicla 2 kg de plástico', 'Plástico', 2),
  Reto('Recicla 1 kg de papel y cartón', 'Papel y cartón', 1),
  Reto('Recicla 5 kg en total', null, 5),
];

// [v5-A] Distritos para el formulario de perfil
const distritos = [
  'Arequipa (Cercado)',
  'Alto Selva Alegre',
  'Cayma',
  'Cerro Colorado',
  'Characato',
  'Jacobo Hunter',
  'José Luis Bustamante y Rivero',
  'Mariano Melgar',
  'Miraflores',
  'Paucarpata',
  'Sabandía',
  'Sachaca',
  'Socabaya',
  'Tiabaya',
  'Uchumayo',
  'Yanahuara',
  'Yura',
  'Otro',
];

const consejos = [
  'Enjuaga los envases antes de reciclarlos: un envase limpio se aprovecha mejor.',
  'Separa tus residuos en casa y ayuda a mantener limpio el paisaje que rodea al Misti.',
  'Las pilas y los celulares viejos no van a la basura común: llévalos a un punto de acopio.',
  'Aplasta las botellas y cajas para que ocupen menos espacio en tu tacho.',
  'Con tus cáscaras de fruta puedes hacer compost para tus plantas.',
  'En casa, el código de colores peruano usa verde para aprovechables, marrón para orgánicos, rojo para peligrosos y negro para el resto.',
];

// Niveles tematicos (cada 100 hojas sube de nivel)
const nivelesTema = ['Semilla', 'Brote', 'Arbusto', 'Árbol', 'Guardián del Misti'];
String nombreNivel(int nivel) =>
    nivelesTema[(nivel - 1).clamp(0, nivelesTema.length - 1)];

Categoria categoriaPorNombre(String n) =>
    categorias.firstWhere((c) => c.nombre == n);

// [v4-4] Inicio de la semana actual (lunes a las 00:00)
DateTime inicioSemana() {
  final h = DateTime.now();
  return DateTime(h.year, h.month, h.day).subtract(Duration(days: h.weekday - 1));
}

double avanceReto(Reto r, List<Registro> h) {
  final ini = inicioSemana();
  return h
      .where((x) =>
          !x.fecha.isBefore(ini) &&
          (r.categoria == null || x.categoria == r.categoria))
      .fold(0.0, (s, x) => s + x.kg);
}

// ---------------------------------------------------------------
// ILUSTRACION PROPIA: paisaje del Misti con la ciudad blanca
// ---------------------------------------------------------------
class MistiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final cielo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF81D4FA), Color(0xFFFFF3E0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), cielo);

    canvas.drawCircle(Offset(w * 0.84, h * 0.2), h * 0.1,
        Paint()..color = const Color(0xFFFFD54F));

    final lateral = Paint()..color = const Color(0xFF90A4AE);
    canvas.drawPath(
        Path()
          ..moveTo(-w * 0.05, h * 0.8)
          ..lineTo(w * 0.17, h * 0.42)
          ..lineTo(w * 0.40, h * 0.8)
          ..close(),
        lateral);
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.6, h * 0.8)
          ..lineTo(w * 0.83, h * 0.5)
          ..lineTo(w * 1.05, h * 0.8)
          ..close(),
        lateral);

    canvas.drawPath(
        Path()
          ..moveTo(w * 0.22, h * 0.82)
          ..lineTo(w * 0.47, h * 0.18)
          ..lineTo(w * 0.53, h * 0.18)
          ..lineTo(w * 0.78, h * 0.82)
          ..close(),
        Paint()..color = const Color(0xFF607D8B));

    canvas.drawPath(
        Path()
          ..moveTo(w * 0.43, h * 0.31)
          ..lineTo(w * 0.47, h * 0.18)
          ..lineTo(w * 0.53, h * 0.18)
          ..lineTo(w * 0.57, h * 0.31)
          ..lineTo(w * 0.5, h * 0.27)
          ..close(),
        Paint()..color = const Color(0xFFECEFF1));

    final edificio = Paint()..color = const Color(0xFFFAFAFA);
    for (int i = 0; i < 10; i++) {
      final alto = h * (0.07 + (i % 3) * 0.035);
      canvas.drawRect(
          Rect.fromLTWH(w * (0.03 + i * 0.1), h * 0.9 - alto, w * 0.07, alto),
          edificio);
    }

    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.87)
          ..quadraticBezierTo(w * 0.5, h * 0.78, w, h * 0.88)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        Paint()..color = const Color(0xFF66BB6A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Ilustracion + foto real opcional encima (si el archivo no existe, no se ve)
class MistiBanner extends StatelessWidget {
  final double? height; // [v5-C] opcional: dentro de AspectRatio toma su tamano
  final String? foto;
  final Widget? child;
  const MistiBanner({super.key, this.height, this.foto, this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: MistiPainter()),
            if (foto != null)
              Image.asset(
                'assets/images/$foto',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// APP PRINCIPAL (tema propio + modo oscuro)
// ---------------------------------------------------------------
class MistiVerdeApp extends StatelessWidget {
  const MistiVerdeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MistiVerde',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: verdeMisti),
        scaffoldBackgroundColor: sillar,
        appBarTheme: const AppBarTheme(
          backgroundColor: verdeMisti,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: verdeMisti, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(
          backgroundColor: verdeOscuro,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const SplashPage(),
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA DE BIENVENIDA (Splash)
// ---------------------------------------------------------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  // [v5-A] Tras la animacion decide: onboarding (primera vez) o la app
  Future<void> _iniciar() async {
    final espera = Future.delayed(const Duration(milliseconds: 2800));
    Perfil? perfil;
    try {
      perfil = await Perfil.cargar();
    } catch (_) {
      // Si falla la lectura, se trata como primera vez
    }
    await espera;
    if (!mounted) return;
    final Perfil? p = perfil;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          p == null ? const OnboardingPage() : HomeShell(perfil: p),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: MistiPainter(), size: Size.infinite),
          Image.asset(
            'assets/images/misti_portada.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          Align(
            alignment: const Alignment(0, -0.55),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(215),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: sillar,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.landscape,
                          size: 56, color: verdeMisti),
                    ),
                    const SizedBox(height: 14),
                    const Text('MistiVerde',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: verdeOscuro)),
                    const SizedBox(height: 6),
                    const Text('Recicla y cuida tu Arequipa',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF33691E))),
                  ],
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.92),
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// [v5-A] ONBOARDING (PageView): 3 pantallas de presentacion
// ---------------------------------------------------------------
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controlador = PageController();
  int _pagina = 0;

  static const _pasos = [
    _PasoOnboarding(
      Icons.category,
      'Aprende a clasificar',
      'Descubre en qué tacho va cada residuo según el código de colores peruano.',
    ),
    _PasoOnboarding(
      Icons.place,
      'Encuentra dónde llevarlo',
      'Consulta puntos de acopio en lista o en el mapa, con la fuente de cada dato.',
    ),
    _PasoOnboarding(
      Icons.emoji_events,
      'Gana hojas y sube de nivel',
      'Registra lo que reciclas, cumple retos semanales y llega a Guardián del Misti.',
    ),
  ];

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _irAlPerfil() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PerfilFormPage()));
  }

  void _continuar() {
    if (_pagina < _pasos.length - 1) {
      _controlador.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _irAlPerfil();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _pasos.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _irAlPerfil,
                    child: const Text('Omitir'),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controlador,
                    onPageChanged: (i) => setState(() => _pagina = i),
                    children: _pasos,
                  ),
                ),
                // Indicador de pagina
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pasos.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _pagina == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _pagina == i ? verdeMisti : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _continuar,
                      child: Text(ultima ? 'Crear mi perfil' : 'Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasoOnboarding extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _PasoOnboarding(this.icono, this.titulo, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AspectRatio: la ilustracion mantiene proporcion 16:9
          AspectRatio(
            aspectRatio: 16 / 9,
            child: MistiBanner(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(215),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, size: 56, color: verdeMisti),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(texto,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// [v5-A] FORMULARIO DE PERFIL (Form + TextFormField + validacion)
// ---------------------------------------------------------------
class PerfilFormPage extends StatefulWidget {
  final Perfil? inicial; // null = primera vez; con valor = editar
  const PerfilFormPage({super.key, this.inicial});

  @override
  State<PerfilFormPage> createState() => _PerfilFormPageState();
}

class _PerfilFormPageState extends State<PerfilFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _alias;
  String? _distrito;
  bool _guardando = false;

  bool get _esEdicion => widget.inicial != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.inicial?.nombre ?? '');
    _alias = TextEditingController(text: widget.inicial?.alias ?? '');
    _distrito = widget.inicial?.distrito;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _alias.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    final perfil = Perfil(_nombre.text.trim(), _alias.text.trim(), _distrito!);
    try {
      await perfil.guardar();
    } catch (_) {
      // Si falla el guardado, la app sigue con el perfil en memoria
    }
    if (!mounted) return;
    if (_esEdicion) {
      Navigator.pop(context, perfil);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeShell(perfil: perfil)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar perfil' : 'Crea tu perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Tus datos se quedan en tu equipo'),
                      subtitle: Text(
                          'No hay servidor ni contraseña. Este perfil solo personaliza la app.'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombre,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length < 2) return 'Escribe tu nombre (mínimo 2 letras)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _alias,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [LengthLimitingTextInputFormatter(15)],
                    decoration: const InputDecoration(
                      labelText: 'Alias (se muestra en la app)',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.length < 3) return 'Mínimo 3 caracteres';
                      if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(t)) {
                        return 'Solo letras, números y guion bajo';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Distrito: FormField con ChoiceChip dentro de un Wrap
                  FormField<String>(
                    initialValue: _distrito,
                    validator: (v) => v == null ? 'Elige tu distrito' : null,
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Distrito',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: distritos
                              .map((d) => ChoiceChip(
                                    label: Text(d),
                                    selected: state.value == d,
                                    onSelected: (_) {
                                      _distrito = d;
                                      state.didChange(d);
                                    },
                                  ))
                              .toList(),
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(state.errorText!,
                                style: TextStyle(color: cs.error, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Consentimiento: FormField<bool> con CheckboxListTile
                  FormField<bool>(
                    initialValue: _esEdicion,
                    validator: (v) =>
                        v == true ? null : 'Debes aceptar para continuar',
                    builder: (state) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: state.value ?? false,
                          onChanged: (v) => state.didChange(v),
                          title: const Text(
                              'Entiendo que mi perfil y mis registros se guardan solo en este equipo.'),
                        ),
                        if (state.hasError)
                          Text(state.errorText!,
                              style: TextStyle(color: cs.error, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: const Icon(Icons.check),
                      label: Text(
                          _esEdicion ? 'Guardar cambios' : 'Entrar a MistiVerde'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// CONTENEDOR PRINCIPAL: barra inferior + estado compartido
// ---------------------------------------------------------------
class HomeShell extends StatefulWidget {
  final Perfil perfil; // [v5-A]
  const HomeShell({super.key, required this.perfil});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _clave = 'registros_mistiverde';
  int _indice = 0;
  late Perfil _perfil; // [v5-A]
  final List<Registro> _historial = [];

  // Las hojas se calculan a partir del historial guardado
  int get _puntosTotal => _historial.fold(0, (s, r) => s + r.puntos);

  @override
  void initState() {
    super.initState();
    _perfil = widget.perfil;
    _cargar();
  }

  // [v4-3] Lee el historial guardado en el equipo
  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datos = prefs.getStringList(_clave) ?? [];
      final lista = datos.map(Registro.desdeTexto).whereType<Registro>().toList();
      if (!mounted) return;
      setState(() {
        _historial
          ..clear()
          ..addAll(lista);
      });
    } catch (_) {
      // Si falla la lectura, la app sigue funcionando en memoria
    }
  }

  // [v4-3] Guarda el historial en el equipo
  Future<void> _persistir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _clave, _historial.map((r) => r.aTexto()).toList());
    } catch (_) {}
  }

  void _guardar(String categoria, double kg) {
    final nivelAntes = _puntosTotal ~/ 100 + 1;
    final p = (kg * 10).round();
    setState(() {
      _historial.insert(0, Registro(categoria, kg, p, DateTime.now()));
    });
    _persistir();
    final nivelDespues = _puntosTotal ~/ 100 + 1;
    final mensaje = nivelDespues > nivelAntes
        ? '¡Subiste a ${nombreNivel(nivelDespues)}! +$p hojas'
        : '¡+$p hojas por reciclar ${kg.toStringAsFixed(1)} kg de ${categoria.toLowerCase()}!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  void _reiniciar() {
    setState(() => _historial.clear());
    _persistir();
  }

  // [v5-C] Elimina un registro (Dismissible) y permite deshacer
  void _eliminar(Registro r) {
    final pos = _historial.indexOf(r);
    if (pos < 0) return;
    setState(() => _historial.removeAt(pos));
    _persistir();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Registro eliminado'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () {
              setState(() {
                final i = pos > _historial.length ? _historial.length : pos;
                _historial.insert(i, r);
              });
              _persistir();
            },
          ),
        ),
      );
  }

  // [v5-A] Editar perfil: abre el formulario y recibe el perfil actualizado
  Future<void> _editarPerfil() async {
    Navigator.pop(context); // cierra el Drawer
    final nuevo = await Navigator.push<Perfil>(
      context,
      MaterialPageRoute(builder: (_) => PerfilFormPage(inicial: _perfil)),
    );
    if (nuevo != null && mounted) setState(() => _perfil = nuevo);
  }

  // [v5-A] Cerrar sesion: borra el perfil local y vuelve al onboarding.
  // Los registros de reciclaje se mantienen en el equipo.
  Future<void> _cerrarSesion() async {
    Navigator.pop(context); // cierra el Drawer
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
            'Se cerrará tu perfil. Tus registros de reciclaje se mantienen en este equipo (puedes borrarlos con «Reiniciar» en Impacto).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Perfil.borrar();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingPage()),
      (route) => false,
    );
  }

  // [v5-A] Menu lateral (Drawer) con el perfil
  Widget _drawer() {
    final nivel = _puntosTotal ~/ 100 + 1;
    void ir(int i) {
      setState(() => _indice = i);
      Navigator.pop(context);
    }

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: verdeMisti),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: sillar,
                  child: Text(_perfil.alias.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: verdeOscuro)),
                ),
                const SizedBox(height: 10),
                Text(_perfil.alias,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('${nombreNivel(nivel)} • ${_perfil.distrito}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            selected: _indice == 0,
            onTap: () => ir(0),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('¿Dónde lo tiro?'),
            selected: _indice == 1,
            onTap: () => ir(1),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: const Text('Puntos'),
            selected: _indice == 2,
            onTap: () => ir(2),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Impacto'),
            selected: _indice == 3,
            onTap: () => ir(3),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar perfil'),
            onTap: _editarPerfil,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'MistiVerde',
                applicationVersion: '5.0 (prototipo académico)',
                applicationIcon:
                    const Icon(Icons.landscape, color: verdeMisti, size: 40),
                children: const [
                  Text(
                      'Prototipo del Laboratorio 4 de Plataformas Emergentes, hecho con Flutter. '
                      'El perfil se guarda solo en este equipo y no es una autenticación. '
                      'Los puntos de acopio vienen de fuentes públicas y deben confirmarse antes de ir. '
                      'El mapa usa datos de OpenStreetMap y necesita internet.'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: _cerrarSesion,
          ),
        ],
      ),
    );
  }

  // Panel inferior: solo categorias que se pueden reciclar
  void _abrirRegistro() {
    final opciones = categorias.where((c) => c.reciclable).toList();
    int seleccion = 0;
    double kg = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registrar reciclaje',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(opciones.length, (i) {
                  return ChoiceChip(
                    avatar: Icon(opciones[i].icono,
                        size: 18, color: opciones[i].color),
                    label: Text(opciones[i].nombre),
                    selected: seleccion == i,
                    onSelected: (_) => setModal(() => seleccion = i),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text('Cantidad: ${kg.toStringAsFixed(1)} kg'),
              Slider(
                value: kg,
                min: 0.5,
                max: 10,
                divisions: 19,
                onChanged: (v) => setModal(() => kg = v),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: Text('Guardar (+${(kg * 10).round()} hojas)'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _guardar(opciones[seleccion].nombre, kg);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      InicioPage(
        puntos: _puntosTotal,
        historial: _historial,
        alias: _perfil.alias,
        onIrClasificador: () => setState(() => _indice = 1),
      ),
      const ClasificadorPage(),
      const PuntosPage(),
      ImpactoPage(
        puntos: _puntosTotal,
        historial: _historial,
        onReiniciar: _reiniciar,
        onEliminar: _eliminar,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('MistiVerde')),
      drawer: _drawer(), // [v5-A]
      // [v4-6] Ancho maximo: en pantallas grandes (Chrome, tablet) no se estira
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child:
                KeyedSubtree(key: ValueKey(_indice), child: paginas[_indice]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirRegistro,
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.search), label: '¿Dónde lo tiro?'),
          NavigationDestination(icon: Icon(Icons.place), label: 'Puntos'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Impacto'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA 1: INICIO
// ---------------------------------------------------------------
class InicioPage extends StatelessWidget {
  final int puntos;
  final List<Registro> historial;
  final String alias; // [v5-A]
  final VoidCallback onIrClasificador;
  const InicioPage({
    super.key,
    required this.puntos,
    required this.historial,
    required this.alias,
    required this.onIrClasificador,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final consejo = consejos[DateTime.now().day % consejos.length];
    // [v5-C] MediaQuery: la altura del banner depende de la orientacion y el ancho
    final media = MediaQuery.of(context);
    final horizontal = media.orientation == Orientation.landscape;
    final alturaBanner =
        horizontal ? 120.0 : (media.size.width >= 600 ? 220.0 : 180.0);
    final ini = inicioSemana();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MistiBanner(
          height: alturaBanner,
          foto: 'misti_portada.jpg',
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 14,
                bottom: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(120),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('¡Hola, $alias!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Tienes $puntos hojas',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: ListTile(
            leading: const Icon(Icons.lightbulb, color: Colors.amber),
            title: const Text('Consejo del día'),
            subtitle: Text(consejo),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onIrClasificador,
                icon: const Icon(Icons.search),
                label: const Text('¿Dónde lo tiro?'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // [v4-4] Retos semanales: el titulo usa Spacer para separar la fecha
        Row(
          children: [
            const Text('Retos de la semana',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('Desde el ${ini.day}/${ini.month}',
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ...retos.map((r) {
          final avance = avanceReto(r, historial);
          final progreso = (avance / r.metaKg).clamp(0.0, 1.0).toDouble();
          final completo = progreso >= 1;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(r.titulo,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Icon(
                        completo ? Icons.emoji_events : Icons.flag_outlined,
                        color: completo ? Colors.amber : cs.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progreso),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, v, _) =>
                        LinearProgressIndicator(value: v, minHeight: 8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '${avance.toStringAsFixed(1)} / ${r.metaKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        const Text('Categorías de residuos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // [v4-6] LayoutBuilder: 3 o 4 columnas segun el ancho disponible
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 480 ? 4 : 3;
            return GridView.count(
              crossAxisCount: columnas,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: categorias.map((c) {
                return Material(
                  color: c.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CategoriaPage(categoria: c)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'cat_${c.nombre}',
                          child: Icon(c.icono, size: 36, color: c.color),
                        ),
                        const SizedBox(height: 6),
                        Text(c.nombre,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ---------------------------------------------------------------
// DETALLE DE CATEGORIA
// ---------------------------------------------------------------
class CategoriaPage extends StatelessWidget {
  final Categoria categoria;
  const CategoriaPage({super.key, required this.categoria});

  @override
  Widget build(BuildContext context) {
    final lista = residuos.where((r) => r.categoria == categoria.nombre).toList();
    final lugares =
        puntos.where((p) => p.acepta.contains(categoria.nombre)).toList();

    return Scaffold(
      // [v5-C] CustomScrollView + SliverAppBar: el encabezado se colapsa al
      // desplazar. Sustituye al AspectRatio que se usaba en la v4.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                title: Text(categoria.nombre),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: categoria.color.shade700),
                      Image.asset(
                        'assets/images/${categoria.foto}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(210),
                            shape: BoxShape.circle,
                          ),
                          child: Hero(
                            tag: 'cat_${categoria.nombre}',
                            child: Icon(categoria.icono,
                                size: 56, color: categoria.color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!categoria.reciclable)
                      Card(
                        color: Colors.red.shade50,
                        child: const ListTile(
                          leading: Icon(Icons.info_outline, color: Colors.red),
                          title: Text('No se registra como reciclaje',
                              style: TextStyle(color: Colors.black87)),
                          subtitle: Text(
                              'Estos residuos no se reciclan en casa. Aquí aprendes dónde deben ir.',
                              style: TextStyle(color: Colors.black87)),
                        ),
                      ),
                    const Text('Qué va en esta categoría',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (lista.isEmpty)
                      const Text(
                          'Aún no hay residuos registrados en esta categoría.')
                    else
                      ...lista.map((r) => Card(
                            child: ListTile(
                              leading:
                                  Icon(categoria.icono, color: categoria.color),
                              title: Text(r.nombre),
                              subtitle:
                                  Text('${r.contenedor.nombre}\n${r.instruccion}'),
                              isThreeLine: true,
                            ),
                          )),
                    const SizedBox(height: 16),
                    if (categoria.reciclable) ...[
                      const Text('Dónde llevarlo',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (lugares.isEmpty)
                        const Text(
                            'No hay puntos de acopio verificados para esta categoría en la app. '
                            'Consulta el programa oficial "Arequipa Recicla" de la Municipalidad Provincial de Arequipa.')
                      else
                        Wrap(
                          spacing: 8,
                          children: lugares
                              .map((p) => Chip(
                                    avatar: const Icon(Icons.location_on,
                                        size: 18),
                                    label: Text(p.nombre),
                                  ))
                              .toList(),
                        ),
                    ],
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA 2: CLASIFICADOR (busqueda + filtro por categoria)
// ---------------------------------------------------------------
class ClasificadorPage extends StatefulWidget {
  const ClasificadorPage({super.key});

  @override
  State<ClasificadorPage> createState() => _ClasificadorPageState();
}

class _ClasificadorPageState extends State<ClasificadorPage> {
  String _busqueda = '';
  String _cat = 'Todos';

  @override
  Widget build(BuildContext context) {
    final filtrados = residuos
        .where((r) =>
            r.nombre.toLowerCase().contains(_busqueda.toLowerCase()) &&
            (_cat == 'Todos' || r.categoria == _cat))
        .toList();
    final opciones = ['Todos', ...categorias.map((c) => c.nombre)];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Busca un residuo (ej. botella)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
        ),
        // [v4-7] Filtro por categoria
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: opciones
                .map((o) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(o),
                        selected: _cat == o,
                        onSelected: (_) => setState(() => _cat = o),
                      ),
                    ))
                .toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
                'Colores de tacho según la NTP 900.058:2019 (ámbito municipal)',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 56, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No se encontró ese residuo'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtrados.length,
                  itemBuilder: (context, i) {
                    final r = filtrados[i];
                    final c = categoriaPorNombre(r.categoria);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c.color.withAlpha(50),
                          child: Icon(c.icono, color: c.color),
                        ),
                        title: Text(r.nombre),
                        subtitle: Text('${r.categoria} • ${r.contenedor.nombre}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: r.contenedor.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            icon: Icon(c.icono, color: c.color, size: 36),
                            title: Text(r.nombre),
                            content: Text(
                                'Va en: ${r.contenedor.nombre}\n\n${r.instruccion}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA 3: PUNTOS DE ACOPIO (datos de fuentes publicas)
// ---------------------------------------------------------------
class PuntosPage extends StatefulWidget {
  const PuntosPage({super.key});

  @override
  State<PuntosPage> createState() => _PuntosPageState();
}

class _PuntosPageState extends State<PuntosPage> {
  String _filtro = 'Todos';

  @override
  Widget build(BuildContext context) {
    final opciones = [
      'Todos',
      ...categorias.where((c) => c.reciclable).map((c) => c.nombre)
    ];
    final lista = _filtro == 'Todos'
        ? puntos
        : puntos.where((p) => p.acepta.contains(_filtro)).toList();

    // [v5-B] DefaultTabController + TabBar + TabBarView: Lista | Mapa.
    // El filtro de arriba se comparte entre las dos pestanas.
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: opciones
                    .map((o) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(o),
                            selected: _filtro == o,
                            onSelected: (_) => setState(() => _filtro = o),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Lista'),
              Tab(text: 'Mapa'),
            ],
          ),
          Expanded(
            child: TabBarView(
              // Sin deslizar entre pestanas: el gesto horizontal es del mapa
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _tabLista(lista),
                _MapaPuntos(lista: lista),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabLista(List<PuntoAcopio> lista) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Programa oficial (antecedente) y aviso de verificacion
        Card(
          color: Colors.green.shade50,
          child: const ListTile(
            leading: Icon(Icons.verified, color: verdeMisti),
            title: Text('Programa oficial: Arequipa Recicla',
                style: TextStyle(color: Colors.black87)),
            subtitle: Text(
                'La Municipalidad Provincial de Arequipa tiene una app que informa fechas y horarios de recojo de material reciclable en tu hogar.',
                style: TextStyle(color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
            'Datos de fuentes públicas. Confirma la vigencia antes de ir: los horarios no están verificados.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.location_off, size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                      'No hay puntos verificados para esta categoría.\nPrueba con el programa Arequipa Recicla.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ...lista.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PuntoPage(punto: p)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'punto_${p.nombre}',
                          child: const Icon(Icons.location_on,
                              color: verdeMisti, size: 34),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(p.ubicacion),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                children: p.acepta
                                    .map((a) => Chip(
                                          label: Text(a,
                                              style:
                                                  const TextStyle(fontSize: 11)),
                                          visualDensity: VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              )),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ---------------------------------------------------------------
// [v5-B] MAPA REAL (flutter_map + teselas de OpenStreetMap)
// Solo se dibujan los puntos con ubicacion; el marcador es una REFERENCIA
// del distrito, no la direccion exacta.
// ---------------------------------------------------------------
class _MapaPuntos extends StatelessWidget {
  final List<PuntoAcopio> lista;
  const _MapaPuntos({required this.lista});

  @override
  Widget build(BuildContext context) {
    final conMapa = lista.where((p) => p.tieneMapa).toList();
    final sinMapa = lista.length - conMapa.length;

    return Column(
      children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(-16.33, -71.62),
              initialZoom: 10.5,
              minZoom: 8,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.misti_verde',
              ),
              MarkerLayer(
                markers: conMapa
                    .map((p) => Marker(
                          point: LatLng(p.lat!, p.lng!),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PuntoPage(punto: p)),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: verdeMisti,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.recycling,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            conMapa.isEmpty
                ? 'Ningún punto de este filtro tiene ubicación verificada en el mapa. Mira la pestaña Lista.'
                : 'Los marcadores indican el centro del distrito, no la dirección exacta.'
                    '${sinMapa > 0 ? ' $sinMapa punto(s) sin ubicación verificada solo aparecen en la Lista.' : ''}'
                    ' El mapa necesita internet.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 72), // espacio para el boton flotante
      ],
    );
  }
}

// ---------------------------------------------------------------
// DETALLE DE UN PUNTO DE ACOPIO
// ---------------------------------------------------------------
class PuntoPage extends StatelessWidget {
  final PuntoAcopio punto;
  const PuntoPage({super.key, required this.punto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(punto.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // [v5-C] AspectRatio: el banner mantiene proporcion 16:7
          AspectRatio(
            aspectRatio: 16 / 7,
            child: MistiBanner(
              foto: 'punto_acopio.jpg',
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(210),
                    shape: BoxShape.circle,
                  ),
                  child: Hero(
                    tag: 'punto_${punto.nombre}',
                    child: const Icon(Icons.location_on,
                        size: 52, color: verdeOscuro),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.place),
                  title: const Text('Ubicación'),
                  subtitle: Text(punto.ubicacion),
                ),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('En el mapa'),
                  subtitle: Text(punto.tieneMapa
                      ? (punto.precision ?? 'Referencia aproximada.')
                      : 'Sin ubicación verificada: no aparece en el mapa.'),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Qué se sabe de este punto'),
                  subtitle: Text(punto.detalle),
                ),
                ListTile(
                  leading: const Icon(Icons.source),
                  title: const Text('Fuente de la información'),
                  subtitle: Text(punto.fuente),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.amber.shade50,
            child: const ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.orange),
              title: Text('Confirma antes de ir',
                  style: TextStyle(color: Colors.black87)),
              subtitle: Text(
                  'Los horarios y la disponibilidad no están verificados y pueden haber cambiado.',
                  style: TextStyle(color: Colors.black87)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Materiales que acepta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: punto.acepta.map((a) {
              final c = categoriaPorNombre(a);
              return Chip(
                avatar: Icon(c.icono, size: 18, color: c.color),
                label: Text(a),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // [v4-5] Funcion real: copia la ubicacion al portapapeles
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copiar ubicación'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: punto.ubicacion));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ubicación copiada'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// PANTALLA 4: MI IMPACTO
// ---------------------------------------------------------------
class ImpactoPage extends StatelessWidget {
  final int puntos;
  final List<Registro> historial;
  final VoidCallback onReiniciar;
  final void Function(Registro) onEliminar; // [v5-C]
  const ImpactoPage({
    super.key,
    required this.puntos,
    required this.historial,
    required this.onReiniciar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nivel = puntos ~/ 100 + 1;
    final progreso = (puntos % 100) / 100;
    final totalKg = historial.fold<double>(0, (s, r) => s + r.kg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MistiBanner(
          height: 120,
          foto: 'reciclaje_general.jpg',
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Tu aporte a Arequipa',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primaryContainer,
                      child: Text('$nivel',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${nombreNivel(nivel)} • Nivel $nivel',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('$puntos hojas'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progreso),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, v, _) =>
                      LinearProgressIndicator(value: v, minHeight: 10),
                ),
                const SizedBox(height: 6),
                Text('${100 - (puntos % 100)} hojas para el siguiente nivel',
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _Estadistica(
                  icono: Icons.scale,
                  valor: '${totalKg.toStringAsFixed(1)} kg',
                  texto: 'Reciclados'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Estadistica(
                  icono: Icons.checklist,
                  valor: '${historial.length}',
                  texto: 'Registros'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // [v4-7] Resumen por categoria con el widget Table
        const Text('Resumen por categoría',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(3),
          },
          children: categorias.where((c) => c.reciclable).map((c) {
            final kgCat = historial
                .where((r) => r.categoria == c.nombre)
                .fold<double>(0, (s, r) => s + r.kg);
            return TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(c.icono, size: 18, color: c.color),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(c.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Text('${kgCat.toStringAsFixed(1)} kg',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13)),
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: LinearProgressIndicator(
                  value: totalKg == 0 ? 0 : kgCat / totalKg,
                  minHeight: 6,
                ),
              ),
            ]);
          }).toList(),
        ),
        const SizedBox(height: 20),

        const Text('Camino del Guardián',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: List.generate(nivelesTema.length, (i) {
            final alcanzado = i < nivel;
            return Chip(
              avatar: Icon(
                alcanzado ? Icons.check_circle : Icons.lock_outline,
                size: 18,
              ),
              label: Text(nivelesTema[i]),
              backgroundColor: alcanzado ? cs.primaryContainer : null,
            );
          }),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            const Text('Historial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (historial.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reiniciar'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reiniciar datos'),
                    content: const Text(
                        'Se borrarán tus registros y tus hojas. ¿Continuar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onReiniciar();
                        },
                        child: const Text('Borrar'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (historial.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Desliza hacia la izquierda para borrar un registro.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        if (historial.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.eco_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Aún no registras nada. Usa el botón "Registrar".',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ...historial.map((r) {
            final c = categoriaPorNombre(r.categoria);
            // [v5-C] Dismissible: deslizar para borrar (con opcion de deshacer)
            return Dismissible(
              key: ObjectKey(r),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onEliminar(r),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.color.withAlpha(50),
                    child: Icon(c.icono, color: c.color),
                  ),
                  title: Text(r.categoria),
                  subtitle: Text(
                      '${r.kg.toStringAsFixed(1)} kg • ${r.fecha.day}/${r.fecha.month}/${r.fecha.year}'),
                  trailing: Text('+${r.puntos} hojas',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _Estadistica extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String texto;
  const _Estadistica(
      {required this.icono, required this.valor, required this.texto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icono, color: cs.onPrimaryContainer),
          const SizedBox(height: 6),
          Text(valor,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer)),
          Text(texto,
              style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}