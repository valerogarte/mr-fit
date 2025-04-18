import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';
import '../models/usuario/usuario.dart';
import '../data/database_helper.dart';
import '../widgets/home/calendar.dart';
import '../widgets/home/daily_steps_activity_kcal.dart';
import '../widgets/home/daily_sleep.dart';
import '../widgets/home/daily_weekly.dart';
import '../widgets/home/daily_trainings.dart';
import '../widgets/home/daily_physical.dart';
import '../widgets/home/daily_nutrition.dart';
import '../providers/usuario_provider.dart';

class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  DateTime _selectedDate = DateTime.now(); // Por defecto, día de hoy.
  List<dynamic> _resumenEntrenamientos = [];
  Set<DateTime> _diasEntrenados = {};

  @override
  void initState() {
    super.initState();
    // Inicializa la base de datos si no existe
    DatabaseHelper.instance.database.then((db) {});
    initializeDateFormatting('es', null);
    _cargarResumenEntrenamientos();
  }

  void _cargarResumenEntrenamientos() async {
    final usuario = ref.read(usuarioProvider);
    await usuario.googleSignInSilently();

    final data = await usuario.getResumenEntrenamientos();
    List<dynamic> resumen = [];
    if (data != null) {
      resumen = data;
    }
    if (usuario.googleIsLoggedIn()) {
      final dataGoogleFit = await usuario.googleGetEntrenamientos30Dias();
      if (dataGoogleFit != null) {
        List<dynamic> googleTrainings = dataGoogleFit.map((session) {
          final startMillis = session['startTimeMillis'];
          final endMillis = session['endTimeMillis'];
          DateTime inicio = DateTime.fromMillisecondsSinceEpoch(int.parse(startMillis));
          DateTime fin = DateTime.fromMillisecondsSinceEpoch(int.parse(endMillis));
          Duration duracion = fin.difference(inicio);
          return {
            "id": session["id"],
            "titulo": (session["description"] != null && session["description"].isNotEmpty) ? session["description"] : usuario.getActivityTypeTitle(session["activityType"]),
            "inicio": inicio.toIso8601String(),
            "duracion": "${duracion.inMinutes} minutos",
            "isGoogleFit": true,
          };
        }).toList();
        resumen.addAll(googleTrainings);
      }
    }
    resumen.sort((a, b) => DateTime.parse(b['inicio']).compareTo(DateTime.parse(a['inicio'])));
    if (mounted) {
      setState(() {
        _resumenEntrenamientos = resumen;
        _diasEntrenados = _resumenEntrenamientos.where((entrenamiento) => entrenamiento['inicio'] != null).map((entrenamiento) {
          DateTime dateTime = DateTime.parse(entrenamiento['inicio']).toLocal();
          return DateTime(dateTime.year, dateTime.month, dateTime.day);
        }).toSet();
      });
    }
  }

  void _refreshCalendar() {
    setState(() {
      _cargarResumenEntrenamientos();
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime today = DateTime.now();
    int daysTrainedLast7Days = _diasEntrenados.where((date) => date.isAfter(today.subtract(Duration(days: 7)))).length;
    int daysTrainedLast30Days = _diasEntrenados.where((date) => date.isAfter(today.subtract(Duration(days: 30)))).length;
    final usuario = ref.read(usuarioProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Fixed CalendarWidget at the top with padding
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: CalendarWidget(
              selectedDate: _selectedDate,
              diasEntrenados: _diasEntrenados,
              onDateSelected: (date) {
                DateTime today = DateTime.now();
                if (date.isAfter(today)) {
                  return;
                }
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(30), // Rounded corners
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: SingleChildScrollView(
                    // padding: const EdgeInsets.all(16), // Padding inside the scrollable area
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25.0),
                            child: Text(
                              DateFormat('EEEE, d \'de\' MMMM', 'es').format(_selectedDate).replaceFirstMapped(RegExp(r'^\w'), (match) => match.group(0)!.toUpperCase()),
                              style: const TextStyle(color: AppColors.textColor, fontSize: 16, fontWeight: FontWeight.bold), // Adjusted text color
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        dailyStatsWidget(day: _selectedDate, usuario: usuario),
                        const SizedBox(height: 15),
                        DailyTrainingsWidget(day: _selectedDate, usuario: usuario),
                        const SizedBox(height: 15),
                        dailySleepWidget(day: _selectedDate, usuario: usuario),
                        const SizedBox(height: 15),
                        DailyNutritionWidget(day: _selectedDate, usuario: usuario),
                        const SizedBox(height: 15),
                        WeeklyStatsWidget(daysTrainedLast30Days: daysTrainedLast30Days, daysTrainedLast7Days: daysTrainedLast7Days),
                        const SizedBox(height: 15),
                        dailyPhysicalWidget(),
                        const SizedBox(height: 15),
                        // Expanded(
                        //   flex: 2,
                        //   child: ListadoEntrenamientos(
                        //     resumenEntrenamientos: _resumenEntrenamientos,
                        //     onDismissed: (context, index, removedTraining) async {
                        //       setState(() {
                        //         _resumenEntrenamientos.removeAt(index);
                        //       });
                        //       if (removedTraining['isGoogleFit'] != true) {
                        //         final entrenamientoObj = await Entrenamiento.loadById(removedTraining['id']);
                        //         if (entrenamientoObj != null) {
                        //           await entrenamientoObj.delete();
                        //         }
                        //       }
                        //       _refreshCalendar();
                        //     },
                        //     onTrainingDeleted: _refreshCalendar,
                        //   ),
                        // ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
