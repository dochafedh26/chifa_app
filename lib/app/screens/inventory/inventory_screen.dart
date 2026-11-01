import 'package:chifa/app/cubits/inventory_cubit.dart';
import 'package:chifa/app/screens/inventory/inventory_form_dialog.dart';
import 'package:chifa/services/db/models/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:chifa/app/utils/responsive.dart';

/// Inventory Management Screen
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<InventoryCubit>().loadInventory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<InventoryCubit>().searchInventory(query);
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => const InventoryFormDialog(),
    );
  }

  void _showStockDialog(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => _StockAdjustmentDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return Column(
      children: [
        // Search and Add
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: isMobile
              ? Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search inventory...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Item'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search inventory...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: isMobile ? 'All' : 'All Items',
            ),
            Tab(
              icon: const Icon(Icons.warning_amber),
              text: isMobile ? 'Low' : 'Low Stock',
            ),
            Tab(
              icon: const Icon(Icons.error),
              text: isMobile ? 'Exp.' : 'Expired',
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _InventoryList(filter: InventoryFilter.all),
              _InventoryList(filter: InventoryFilter.lowStock),
              _InventoryList(filter: InventoryFilter.expired),
            ],
          ),
        ),
      ],
    );
  }
}

enum InventoryFilter { all, lowStock, expired }

class _InventoryList extends StatelessWidget {
  final InventoryFilter filter;

  const _InventoryList({required this.filter});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        if (state is InventoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is InventoryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('Error: ${state.message}'),
              ],
            ),
          );
        }

        if (state is InventoryLoaded) {
          var items = state.items;

          // Apply filters
          if (filter == InventoryFilter.lowStock) {
            items = items.where((item) => item.quantity < 10).toList();
          } else if (filter == InventoryFilter.expired) {
            final now = DateTime.now();
            items = items.where((item) {
              final exp = item.expirationDate;
              return exp != null && exp.isBefore(now);
            }).toList();
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    filter == InventoryFilter.all
                        ? 'No inventory items'
                        : filter == InventoryFilter.lowStock
                        ? 'No low stock items'
                        : 'No expired items',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _InventoryItemCard(
                item: item,
                onAdjustStock: () => context
                    .findAncestorStateOfType<_InventoryScreenState>()
                    ?._showStockDialog(item),
              );
            },
          );
        }

        return const Center(child: Text('No data available'));
      },
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onAdjustStock;

  const _InventoryItemCard({required this.item, required this.onAdjustStock});

  bool get _isLowStock => item.quantity < 10;
  bool get _isExpired {
    final exp = item.expirationDate;
    return exp != null && exp.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _isExpired
          ? Colors.red.shade50
          : _isLowStock
          ? Colors.orange.shade50
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getCategoryColor(item.category).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(item.category),
            color: _getCategoryColor(item.category),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.itemName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_isExpired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'EXPIRED',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            if (_isLowStock && !_isExpired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LOW',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Category: ${_formatCategory(item.category)}'),
            Text('Quantity: ${item.quantity} ${_getUnit(item.category)}'),
            Text('Unit Price: ${item.unitPrice.toStringAsFixed(2)} DA'),
            if (item.expirationDate != null)
              Text(
                'Expires: ${DateFormat('dd/MM/yyyy').format(item.expirationDate!)}',
              ),
            if (item.supplierName != null && item.supplierName!.isNotEmpty)
              Text('Supplier: ${item.supplierName}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart),
          onPressed: onAdjustStock,
          tooltip: 'Adjust Stock',
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatCategory(InventoryCategory category) {
    return category.name
        .split('_')
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join(' ');
  }

  String _getUnit(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.medicine:
        return 'units';
      case InventoryCategory.equipment:
        return 'items';
      case InventoryCategory.supplies:
        return 'units';
    }
  }

  Color _getCategoryColor(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.medicine:
        return Colors.blue;
      case InventoryCategory.equipment:
        return Colors.purple;
      case InventoryCategory.supplies:
        return Colors.green;
    }
  }

  IconData _getCategoryIcon(InventoryCategory category) {
    switch (category) {
      case InventoryCategory.medicine:
        return Icons.medication;
      case InventoryCategory.equipment:
        return Icons.engineering;
      case InventoryCategory.supplies:
        return Icons.inventory_2;
    }
  }
}

class _StockAdjustmentDialog extends StatefulWidget {
  final InventoryItem item;

  const _StockAdjustmentDialog({required this.item});

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _quantityController = TextEditingController();
  bool _isAdding = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_isAdding) {
      context.read<InventoryCubit>().addStock(widget.item.itemId!, quantity);
    } else {
      context.read<InventoryCubit>().removeStock(widget.item.itemId!, quantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryCubit, InventoryState>(
      listener: (context, state) {
        setState(() => _isLoading = false);
        if (state is InventoryOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: AlertDialog(
        title: Text('Adjust Stock - ${widget.item.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Stock: ${widget.item.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Add Stock'),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Remove Stock'),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {_isAdding},
              onSelectionChanged: (selected) =>
                  setState(() => _isAdding = selected.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_cart),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isAdding ? 'Add Stock' : 'Remove Stock'),
          ),
        ],
      ),
    );
  }
}
