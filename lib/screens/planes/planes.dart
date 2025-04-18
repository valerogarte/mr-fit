// planes.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entrenamiento/entrenamiento_dias.dart';
import '../../utils/colors.dart';
import '../../models/usuario/usuario.dart';
import '../../models/rutina/rutina.dart';
import '../../models/rutina/grupo.dart';
import '../../providers/usuario_provider.dart';
import '../../widgets/not_found/not_found.dart';

class PlanesPage extends ConsumerStatefulWidget {
  const PlanesPage({super.key});

  @override
  ConsumerState<PlanesPage> createState() => _PlanesPageState();
}

class _PlanesPageState extends ConsumerState<PlanesPage> {
  Map<Grupo, List<Rutina>> gruposConRutinas = {};
  bool isLoading = true;
  int? rutinaActualId;

  @override
  void initState() {
    super.initState();
    fetchPlanes();
  }

  Future<void> fetchPlanes() async {
    setState(() => isLoading = true);
    final usuario = ref.read(usuarioProvider);
    final rutinaActual = await usuario.getRutinaActual();
    rutinaActualId = rutinaActual?.id;
    final fetchedRutinas = await usuario.getRutinas();

    if (fetchedRutinas != null) {
      final ids = fetchedRutinas.where((r) => r.grupoId != null).map((r) => r.grupoId!).toSet();
      final gruposList = await Future.wait(ids.map((id) => Grupo.loadById(id)));
      final gruposMap = {for (var g in gruposList.whereType<Grupo>()) g.id: g};

      final temp = <Grupo, List<Rutina>>{};
      for (var r in fetchedRutinas) {
        if (r.grupoId != null && gruposMap.containsKey(r.grupoId)) {
          temp.putIfAbsent(gruposMap[r.grupoId]!, () => []).add(r);
        }
      }

      final gruposOrdenados = temp.keys.toList()..sort((a, b) => (b.peso ?? 0).compareTo(a.peso ?? 0));

      final sortedMap = <Grupo, List<Rutina>>{};
      for (var g in gruposOrdenados) {
        final lista = temp[g]!..sort((r1, r2) => (r2.peso ?? 0).compareTo(r1.peso ?? 0));
        sortedMap[g] = lista;
      }

      setState(() {
        gruposConRutinas = sortedMap;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los datos.')),
      );
    }
  }

  void _onReorderRutinas(Grupo grupo, int oldIndex, int newIndex) {
    // 1. Reordeno localmente
    final list = List<Rutina>.from(gruposConRutinas[grupo]!);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    // 2. Calculo nuevos pesos y actualizo estado YA
    final length = list.length;
    final updated = <Rutina>[];
    for (var i = 0; i < length; i++) {
      final peso = length - i;
      final r = list[i];
      updated.add(Rutina(
        id: r.id,
        titulo: r.titulo,
        imagen: r.imagen,
        grupoId: r.grupoId,
        peso: peso,
      ));
    }
    setState(() {
      gruposConRutinas[grupo] = updated;
    });

    // 3. En segundo plano, persisto en la BD
    for (var r in updated) {
      r.setPeso(r.peso!);
    }
  }

  Future<void> _establecerRutinaActual(Rutina rutina) async {
    final usuario = ref.read(usuarioProvider);
    if (rutinaActualId == rutina.id) {
      await usuario.setRutinaActual(null);
      setState(() => rutinaActualId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rutina actual deseleccionada.')));
    } else {
      final success = await usuario.setRutinaActual(rutina.id);
      if (success) {
        setState(() => rutinaActualId = rutina.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${rutina.titulo} establecida como rutina actual.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al establecer la rutina actual.')));
      }
    }
  }

  Future<void> _mostrarDialogoNuevoPlan() async {
    String nuevoTitulo = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Nuevo Plan', style: TextStyle(color: AppColors.whiteText)),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Título del rutina',
            labelStyle: TextStyle(color: AppColors.whiteText),
          ),
          style: const TextStyle(color: AppColors.whiteText),
          onChanged: (v) => nuevoTitulo = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.whiteText)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nuevoTitulo.isNotEmpty) {
                Navigator.pop(context);
                final usuario = ref.read(usuarioProvider);
                final nuevoPlan = await usuario.crearRutina(titulo: nuevoTitulo);
                final grupo = await Grupo.loadById(nuevoPlan.grupoId!);
                if (grupo != null) {
                  setState(() {
                    gruposConRutinas.putIfAbsent(grupo, () => []).add(nuevoPlan);
                    fetchPlanes();
                  });
                }
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarRutina(String rutinaId) async {
    final rutina = gruposConRutinas.values.expand((l) => l).firstWhere((r) => r.id.toString() == rutinaId);
    final ok = await rutina.delete();
    if (ok) {
      setState(() {
        final grupo = gruposConRutinas.keys.firstWhere((g) => gruposConRutinas[g]!.any((r) => r.id.toString() == rutinaId));
        gruposConRutinas[grupo]!.removeWhere((r) => r.id.toString() == rutinaId);
        if (gruposConRutinas[grupo]!.isEmpty) gruposConRutinas.remove(grupo);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al eliminar la rutina.')));
    }
  }

  Future<void> _mostrarDialogoEditarPlan(Rutina rutina) async {
    String nuevoTitulo = rutina.titulo;
    bool esActual = rutinaActualId == rutina.id;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Editar Plan', style: TextStyle(color: AppColors.whiteText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: nuevoTitulo),
                decoration: const InputDecoration(
                  labelText: 'Título del rutina',
                  labelStyle: TextStyle(color: AppColors.whiteText),
                ),
                style: const TextStyle(color: AppColors.whiteText),
                onChanged: (v) => nuevoTitulo = v,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rutina actual', style: TextStyle(color: AppColors.whiteText)),
                  Switch(
                    value: esActual,
                    onChanged: (valor) {
                      setStateSB(() => esActual = valor);
                      _establecerRutinaActual(rutina);
                    },
                    activeColor: AppColors.secondaryColor,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.background),
              onPressed: () async {
                Navigator.pop(context);
                final confirma = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    title: const Text('Eliminar Plan', style: TextStyle(color: AppColors.whiteText)),
                    content: const Text('¿Seguro que quieres eliminar la rutina?', style: TextStyle(color: AppColors.whiteText)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.whiteText))),
                      ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
                    ],
                  ),
                );
                if (confirma == true) await _eliminarRutina(rutina.id.toString());
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.whiteText)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nuevoTitulo.isNotEmpty) {
                  Navigator.pop(context);
                  await rutina.rename(nuevoTitulo);
                  setState(() {
                    final grupo = gruposConRutinas.keys.firstWhere((g) => gruposConRutinas[g]!.contains(rutina));
                    final idx = gruposConRutinas[grupo]!.indexWhere((r) => r.id == rutina.id);
                    gruposConRutinas[grupo]![idx] = Rutina(
                      id: rutina.id,
                      titulo: nuevoTitulo,
                      imagen: rutina.imagen,
                      grupoId: rutina.grupoId,
                      peso: rutina.peso,
                    );
                  });
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Rutinas"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : gruposConRutinas.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: NotFoundData(
                    title: 'Sin rutinas',
                    textNoResults: 'Puedes crear la primera pulsando "+".',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: gruposConRutinas.keys.length,
                  itemBuilder: (ctx, i) {
                    final grupo = gruposConRutinas.keys.elementAt(i);
                    final rutinas = gruposConRutinas[grupo]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            grupo.titulo,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteText,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 120,
                          child: grupo.id == 1
                              ? ReorderableListView(
                                  scrollDirection: Axis.horizontal,
                                  onReorder: (oldIndex, newIndex) => _onReorderRutinas(grupo, oldIndex, newIndex),
                                  children: rutinas.map((rutina) {
                                    final esActual = rutina.id == rutinaActualId;
                                    return Container(
                                      key: ValueKey(rutina.id),
                                      width: 200,
                                      margin: const EdgeInsets.only(right: 10),
                                      child: Card(
                                        color: esActual ? AppColors.advertencia : AppColors.cardBackground,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        elevation: esActual ? 8 : 4,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(15),
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EntrenamientoDiasPage(rutina: rutina),
                                            ),
                                          ),
                                          // sin onLongPress aquí
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Column(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        rutina.titulo,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: esActual ? AppColors.background : Colors.white,
                                                        ),
                                                      ),
                                                      if (esActual)
                                                        const Padding(
                                                          padding: EdgeInsets.only(top: 4),
                                                          child: Text(
                                                            "Rutina Actual",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors.background,
                                                              fontStyle: FontStyle.italic,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.edit,
                                                    color: esActual ? AppColors.background : AppColors.textColor,
                                                  ),
                                                  onPressed: () => _mostrarDialogoEditarPlan(rutina),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: rutinas.map((rutina) {
                                      final esActual = rutina.id == rutinaActualId;
                                      return Container(
                                        width: 200,
                                        margin: const EdgeInsets.only(right: 10),
                                        child: Card(
                                          color: esActual ? AppColors.advertencia : AppColors.cardBackground,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          elevation: esActual ? 8 : 4,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(15),
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EntrenamientoDiasPage(rutina: rutina),
                                              ),
                                            ),
                                            // onLongPress: () => _establecerRutinaActual(rutina),
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          rutina.titulo,
                                                          textAlign: TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.bold,
                                                            color: esActual ? AppColors.background : Colors.white,
                                                          ),
                                                        ),
                                                        if (esActual)
                                                          const Padding(
                                                            padding: EdgeInsets.only(top: 4),
                                                            child: Text(
                                                              "Rutina Actual",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors.background,
                                                                fontStyle: FontStyle.italic,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.edit,
                                                      color: esActual ? AppColors.background : AppColors.textColor,
                                                    ),
                                                    onPressed: () => _mostrarDialogoEditarPlan(rutina),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevoPlan,
        backgroundColor: gruposConRutinas.isEmpty ? AppColors.advertencia : AppColors.secondaryColor,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
  }
}
