import 'package:chifa/app/cubits/billing_cubit.dart';
import 'package:chifa/app/cubits/soins_service_cubit.dart';
import 'package:chifa/app/utils/responsive.dart';
import 'package:chifa/services/db/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ServicesSettingsTab extends StatefulWidget {
  const ServicesSettingsTab({super.key});

  @override
  State<ServicesSettingsTab> createState() => _ServicesSettingsTabState();
}

class _ServicesSettingsTabState extends State<ServicesSettingsTab> {
  int _selectedCategoryIndex = 0; // 0: Actes Médicaux, 1: Soins & Injections
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<BillingCubit>().loadServices();
    context.read<SoinsServiceCubit>().loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddEditServiceDialog({Service? service}) {
    showDialog(
      context: context,
      builder: (context) => _ActServiceDialog(service: service),
    );
  }

  void _openAddEditSoinDialog({SoinsService? soin}) {
    showDialog(
      context: context,
      builder: (context) => _SoinServiceDialog(soin: soin),
    );
  }

  void _confirmDeleteService(Service service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer l'acte médical"),
        content: Text('Voulez-vous vraiment supprimer "${service.serviceName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (service.serviceId != null) {
                context.read<BillingCubit>().deleteService(service.serviceId!);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSoin(SoinsService soin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le soin'),
        content: Text('Voulez-vous vraiment supprimer "${soin.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (soin.id != null) {
                context.read<SoinsServiceCubit>().deleteService(soin.id!);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;

    return MultiBlocListener(
      listeners: [
        BlocListener<BillingCubit, BillingState>(
          listener: (context, state) {
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        BlocListener<SoinsServiceCubit, SoinsServiceState>(
          listener: (context, state) {
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
      child: Column(
        children: [
          // Top controls: Category Toggle, Search Bar, Add Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCategoryToggle(theme),
                      const SizedBox(height: 10),
                      _buildSearchBar(),
                      const SizedBox(height: 10),
                      _buildAddButton(),
                    ],
                  )
                : Row(
                    children: [
                      _buildCategoryToggle(theme),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 16),
                      _buildAddButton(),
                    ],
                  ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: _selectedCategoryIndex == 0
                ? _buildActsList(theme)
                : _buildSoinsList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle(ThemeData theme) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment<int>(
          value: 0,
          label: Text('Actes Médicaux'),
          icon: Icon(Icons.medical_services_outlined, size: 18),
        ),
        ButtonSegment<int>(
          value: 1,
          label: Text('Soins & Injections'),
          icon: Icon(Icons.vaccines_outlined, size: 18),
        ),
      ],
      selected: {_selectedCategoryIndex},
      onSelectionChanged: (newSelection) {
        setState(() {
          _selectedCategoryIndex = newSelection.first;
        });
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: _selectedCategoryIndex == 0
            ? 'Rechercher un acte médical...'
            : 'Rechercher un soin / injection...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim().toLowerCase();
        });
      },
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () {
        if (_selectedCategoryIndex == 0) {
          _openAddEditServiceDialog();
        } else {
          _openAddEditSoinDialog();
        }
      },
      icon: const Icon(Icons.add),
      label: Text(
        _selectedCategoryIndex == 0 ? 'Ajouter Acte' : 'Ajouter Soin',
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildActsList(ThemeData theme) {
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        if (state.isLoading && state.services.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = state.services.where((s) {
          if (_searchQuery.isEmpty) return true;
          final name = s.serviceName.toLowerCase();
          final spec = (s.specialization ?? '').toLowerCase();
          return name.contains(_searchQuery) || spec.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'Aucun acte médical configuré'
                      : 'Aucun résultat pour "$_searchQuery"',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final service = filtered[index];
            final clinicShare = (service.price - service.doctorCommission).clamp(0.0, double.infinity);
            final isMobile = context.isMobile;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.medical_services_outlined,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.serviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              if (service.specialization != null && service.specialization!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    service.specialization!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isMobile) ...[
                          _buildPriceTag('Tarif Total', '${service.price.toStringAsFixed(0)} DA', theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          _buildPriceTag('Com. Médecin', '${service.doctorCommission.toStringAsFixed(0)} DA', Colors.teal),
                          const SizedBox(width: 16),
                          _buildPriceTag('Part Clinique', '${clinicShare.toStringAsFixed(0)} DA', Colors.blueGrey),
                          const SizedBox(width: 8),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: Colors.blueGrey[700],
                              tooltip: 'Modifier',
                              onPressed: () => _openAddEditServiceDialog(service: service),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              tooltip: 'Supprimer',
                              onPressed: () => _confirmDeleteService(service),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPriceTag('Tarif Total', '${service.price.toStringAsFixed(0)} DA', theme.colorScheme.primary),
                          _buildPriceTag('Com. Médecin', '${service.doctorCommission.toStringAsFixed(0)} DA', Colors.teal),
                          _buildPriceTag('Part Clinique', '${clinicShare.toStringAsFixed(0)} DA', Colors.blueGrey),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSoinsList(ThemeData theme) {
    return BlocBuilder<SoinsServiceCubit, SoinsServiceState>(
      builder: (context, state) {
        if (state.isLoading && state.services.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = state.services.where((s) {
          if (_searchQuery.isEmpty) return true;
          return s.nom.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vaccines_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isEmpty
                      ? 'Aucun soin configuré'
                      : 'Aucun résultat pour "$_searchQuery"',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final soin = filtered[index];
            final clinicShare = (soin.price - soin.doctorCommission).clamp(0.0, double.infinity);
            final isMobile = context.isMobile;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.vaccines_outlined,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            soin.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!isMobile) ...[
                          _buildPriceTag('Tarif Total', '${soin.price.toStringAsFixed(0)} DA', theme.colorScheme.primary),
                          const SizedBox(width: 16),
                          _buildPriceTag('Com. Médecin', '${soin.doctorCommission.toStringAsFixed(0)} DA', Colors.teal),
                          const SizedBox(width: 16),
                          _buildPriceTag('Part Clinique', '${clinicShare.toStringAsFixed(0)} DA', Colors.blueGrey),
                          const SizedBox(width: 8),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: Colors.blueGrey[700],
                              tooltip: 'Modifier',
                              onPressed: () => _openAddEditSoinDialog(soin: soin),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              tooltip: 'Supprimer',
                              onPressed: () => _confirmDeleteSoin(soin),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isMobile) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPriceTag('Tarif Total', '${soin.price.toStringAsFixed(0)} DA', theme.colorScheme.primary),
                          _buildPriceTag('Com. Médecin', '${soin.doctorCommission.toStringAsFixed(0)} DA', Colors.teal),
                          _buildPriceTag('Part Clinique', '${clinicShare.toStringAsFixed(0)} DA', Colors.blueGrey),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPriceTag(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Dialog for Adding/Editing an Acte Médical (Service)
class _ActServiceDialog extends StatefulWidget {
  final Service? service;

  const _ActServiceDialog({this.service});

  @override
  State<_ActServiceDialog> createState() => _ActServiceDialogState();
}

class _ActServiceDialogState extends State<_ActServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specController;
  late final TextEditingController _priceController;
  late final TextEditingController _commissionController;

  double _price = 0.0;
  double _commission = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service?.serviceName ?? '');
    _specController = TextEditingController(text: widget.service?.specialization ?? '');
    _price = widget.service?.price ?? 0.0;
    _commission = widget.service?.doctorCommission ?? 0.0;
    _priceController = TextEditingController(text: _price > 0 ? _price.toStringAsFixed(0) : '');
    _commissionController = TextEditingController(text: _commission > 0 ? _commission.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0.0;
    final name = _nameController.text.trim();
    final spec = _specController.text.trim().isEmpty ? null : _specController.text.trim();

    if (widget.service != null) {
      final updated = widget.service!.copyWith(
        serviceName: name,
        price: price,
        doctorCommission: commission,
        specialization: spec,
      );
      context.read<BillingCubit>().updateService(widget.service!.serviceId!, updated);
    } else {
      final newService = Service(
        serviceName: name,
        price: price,
        doctorCommission: commission,
        specialization: spec,
      );
      context.read<BillingCubit>().createService(newService);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.service != null;
    final clinicShare = (_price - _commission).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Text(isEditing ? "Modifier l'acte médical" : "Nouvel acte médical"),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width - 64
            : 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nom de l'acte *",
                    hintText: 'Ex: Consultation Générale, ECG, Suture...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medical_services_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return "Veuillez saisir le nom de l'acte";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _specController,
                  decoration: const InputDecoration(
                    labelText: 'Spécialisation (Optionnel)',
                    hintText: 'Ex: Généraliste, Cardiologie, ORL...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tarif Total (DA) *',
                          border: OutlineInputBorder(),
                          suffixText: 'DA',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Tarif requis';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            _price = double.tryParse(val.trim()) ?? 0.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _commissionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Com. Médecin (DA)',
                          border: OutlineInputBorder(),
                          suffixText: 'DA',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Montant invalide';
                          }
                          if (parsed > _price) {
                            return 'Commission > Prix';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            _commission = double.tryParse(val.trim()) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Part nette de la clinique :',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      Text(
                        '${clinicShare.toStringAsFixed(0)} DA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}

/// Dialog for Adding/Editing a Soin / Injection
class _SoinServiceDialog extends StatefulWidget {
  final SoinsService? soin;

  const _SoinServiceDialog({this.soin});

  @override
  State<_SoinServiceDialog> createState() => _SoinServiceDialogState();
}

class _SoinServiceDialogState extends State<_SoinServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _commissionController;

  double _price = 0.0;
  double _commission = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.soin?.nom ?? '');
    _price = widget.soin?.price ?? 0.0;
    _commission = widget.soin?.doctorCommission ?? 0.0;
    _priceController = TextEditingController(text: _price > 0 ? _price.toStringAsFixed(0) : '');
    _commissionController = TextEditingController(text: _commission > 0 ? _commission.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final commission = double.tryParse(_commissionController.text.trim()) ?? 0.0;
    final name = _nameController.text.trim();

    if (widget.soin != null) {
      final updated = widget.soin!.copyWith(
        nom: name,
        price: price,
        doctorCommission: commission,
      );
      context.read<SoinsServiceCubit>().updateService(widget.soin!.id!, updated);
    } else {
      final newSoin = SoinsService(
        nom: name,
        price: price,
        doctorCommission: commission,
      );
      context.read<SoinsServiceCubit>().createService(newSoin);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.soin != null;
    final clinicShare = (_price - _commission).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Text(isEditing ? 'Modifier le soin / injection' : 'Nouveau soin / injection'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? MediaQuery.of(context).size.width - 64
            : 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du soin / médicament *',
                    hintText: 'Ex: Injection IM/IV, Spasfon 40mg, Pansement...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vaccines_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Veuillez saisir le nom du soin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tarif Total (DA) *',
                          border: OutlineInputBorder(),
                          suffixText: 'DA',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Tarif requis';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            _price = double.tryParse(val.trim()) ?? 0.0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _commissionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Com. Médecin (DA)',
                          border: OutlineInputBorder(),
                          suffixText: 'DA',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < 0) {
                            return 'Montant invalide';
                          }
                          if (parsed > _price) {
                            return 'Commission > Prix';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          setState(() {
                            _commission = double.tryParse(val.trim()) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Part nette de la clinique :',
                        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                      Text(
                        '${clinicShare.toStringAsFixed(0)} DA',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Enregistrer' : 'Créer'),
        ),
      ],
    );
  }
}
