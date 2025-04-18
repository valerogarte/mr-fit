part of 'ejercicios_buscar.dart';

// Declare abstract getters and setters for private fields used in the mixin.
abstract class _EjerciciosBuscarFields {
  List<Musculo> get _musculos;
  set _musculos(List<Musculo> value);

  List<Equipamiento> get _equipamientos;
  set _equipamientos(List<Equipamiento> value);

  List<Categoria> get _categorias;
  set _categorias(List<Categoria> value);

  bool get _isLoading;
  set _isLoading(bool value);

  TextEditingController get _nombreController;

  List<Ejercicio> get _ejercicios;
  set _ejercicios(List<Ejercicio> value);

  List<Ejercicio> get _ejerciciosSeleccionados;

  Timer? get _debounce;
  set _debounce(Timer? value);

  Musculo? get _musculoPrimarioSeleccionado;
  set _musculoPrimarioSeleccionado(Musculo? value);

  Musculo? get _musculoSecundarioSeleccionado;
  set _musculoSecundarioSeleccionado(Musculo? value);

  Categoria? get _categoriaSeleccionada;
  set _categoriaSeleccionada(Categoria? value);

  Equipamiento? get _equipamientoSeleccionado;
  set _equipamientoSeleccionado(Equipamiento? value);
}

mixin EjerciciosBuscarLogic on State<EjerciciosBuscarPage> implements _EjerciciosBuscarFields {
  @override
  void initState() {
    super.initState();
    _loadFiltrosData();
  }

  Future<void> _loadFiltrosData() async {
    final data = await ModeloDatos().getDatosFiltrosEjercicios();
    if (data != null) {
      setState(() {
        _musculos = (data['musculos'] as List).map((json) => Musculo.fromJson(json)).toList();
        _equipamientos = (data['equipamientos'] as List).map((json) => Equipamiento.fromJson(json)).toList();
        _categorias = (data['categorias'] as List).map((json) => Categoria.fromJson(json)).toList();
      });
      _buscarEjercicios();
    } else {
      // Manejar error si es necesario
    }
  }

  Future<void> _buscarEjercicios() async {
    setState(() {
      _isLoading = true;
    });
    final filtros = {
      'nombre': _nombreController.text,
      'musculo_primario': _musculoPrimarioSeleccionado != null ? _musculoPrimarioSeleccionado!.id.toString() : '',
      'musculo_secundario': _musculoSecundarioSeleccionado != null ? _musculoSecundarioSeleccionado!.id.toString() : '',
      'categoria': _categoriaSeleccionada != null ? _categoriaSeleccionada!.id.toString() : '',
      'equipamiento': _equipamientoSeleccionado != null ? _equipamientoSeleccionado!.id.toString() : '',
    };
    // Cast filtros to Map<String, String>
    final nuevosEjercicios = await ModeloDatos().buscarEjercicios(filtros.cast<String, String>());
    if (nuevosEjercicios != null) {
      final ejerciciosFiltrados = nuevosEjercicios.where((ejercicio) => !_ejerciciosSeleccionados.contains(ejercicio)).toList();
      setState(() {
        _ejercicios = ejerciciosFiltrados;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged([String? _]) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _buscarEjercicios);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<T?> _mostrarSelector<T>({
    required String titulo,
    required List<T> items,
    required String Function(T) itemAsString,
    required String Function(T)? imageUrl,
    T? valorSeleccionado,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                ListTile(
                  title: Text(
                    titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      ListTile(
                        leading: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.clear),
                        ),
                        title: const Text('Cualquiera'),
                        onTap: () => Navigator.pop(context, null),
                      ),
                      ...items.map((T item) {
                        final image = imageUrl != null && imageUrl(item).isNotEmpty ? imageUrl(item) : 'https://cdn-icons-png.freepik.com/512/105/105376.png';
                        return ListTile(
                          leading: SizedBox(
                            width: 40,
                            height: 40,
                            child: Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image_not_supported);
                              },
                            ),
                          ),
                          title: Text(itemAsString(item)),
                          onTap: () => Navigator.pop(context, item),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _seleccionarMusculoPrimario() async {
    final Musculo? musculoSeleccionado = await _mostrarSelector<Musculo>(
      titulo: 'Seleccione Músculo Principal',
      items: _musculos,
      itemAsString: (Musculo m) => m.titulo,
      imageUrl: (Musculo m) => m.imagen,
      valorSeleccionado: _musculoPrimarioSeleccionado,
    );
    setState(() {
      _musculoPrimarioSeleccionado = musculoSeleccionado;
    });
    _onFilterChanged();
  }

  void _seleccionarMusculoSecundario() async {
    final Musculo? musculoSeleccionado = await _mostrarSelector<Musculo>(
      titulo: 'Seleccione Músculo Secundario',
      items: _musculos,
      itemAsString: (Musculo m) => m.titulo,
      imageUrl: (Musculo m) => m.imagen,
      valorSeleccionado: _musculoSecundarioSeleccionado,
    );
    setState(() {
      _musculoSecundarioSeleccionado = musculoSeleccionado;
    });
    _onFilterChanged();
  }

  void _seleccionarCategoria() async {
    final Categoria? categoriaSeleccionada = await _mostrarSelector<Categoria>(
      titulo: 'Seleccione Categoría',
      items: _categorias,
      itemAsString: (Categoria c) => c.titulo,
      imageUrl: (Categoria c) => c.imagen,
      valorSeleccionado: _categoriaSeleccionada,
    );
    setState(() {
      _categoriaSeleccionada = categoriaSeleccionada;
    });
    _onFilterChanged();
  }

  void _seleccionarEquipamiento() async {
    final Equipamiento? equipamientoSeleccionado = await _mostrarSelector<Equipamiento>(
      titulo: 'Seleccione Equipamiento',
      items: _equipamientos,
      itemAsString: (Equipamiento e) => e.titulo,
      imageUrl: (Equipamiento e) => e.imagen,
      valorSeleccionado: _equipamientoSeleccionado,
    );
    setState(() {
      _equipamientoSeleccionado = equipamientoSeleccionado;
    });
    _onFilterChanged();
  }

  Widget _buildFilterTile({
    required String title,
    required String subtitle,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.cardBackground,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: AppColors.whiteText),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textColor),
        ),
        trailing: imageUrl.isNotEmpty
            ? SizedBox(
                width: 40,
                height: 40,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported);
                  },
                ),
              )
            : const Icon(Icons.arrow_drop_down, color: AppColors.whiteText),
        onTap: onTap,
      ),
    );
  }

  Future<void> _agregarEjerciciosSeleccionados() async {
    bool errorOcurrido = false;
    for (final ejercicio in _ejerciciosSeleccionados) {
      final nuevoEjercicio = await widget.sesion.insertarEjercicioPersonalizado(ejercicio);
      if (nuevoEjercicio == null) {
        errorOcurrido = true;
        break;
      }
    }
    if (errorOcurrido) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al agregar los ejercicios.')),
      );
    } else {
      Navigator.pop(context);
    }
  }
}
