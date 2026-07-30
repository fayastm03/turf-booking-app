import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/owner_bloc.dart';

class AddTurfScreen extends StatefulWidget {
  const AddTurfScreen({super.key});

  @override
  State<AddTurfScreen> createState() => _AddTurfScreenState();
}

class _AddTurfScreenState extends State<AddTurfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _openController = TextEditingController(text: "06:00");
  final _closeController = TextEditingController(text: "23:00");

  String _selectedCityId = 'c0a37340-dfbd-497b-83c8-ee1bc7f0b5d9'; // Default Mumbai

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _openController.dispose();
    _closeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Turf Facility'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocConsumer<OwnerBloc, OwnerState>(
        listener: (context, state) {
          if (state is OwnerLoaded) {
            if (state.actionSuccessMsg != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.actionSuccessMsg!), backgroundColor: Colors.green),
              );
              context.read<OwnerBloc>().add(ClearOwnerStatus());
              context.pop(); // Pop back on success
            }
            if (state.actionError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.actionError!), backgroundColor: theme.colorScheme.error),
              );
              context.read<OwnerBloc>().add(ClearOwnerStatus());
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is OwnerLoaded && state.isActionInProgress;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Facility Details',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Turf Name (e.g. KickOff Arena)',
                    validator: (v) => v == null || v.length < 3 ? 'Name must be at least 3 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  // Address
                  _buildTextField(
                    controller: _addressController,
                    hint: 'Address',
                    validator: (v) => v == null || v.length < 5 ? 'Address must be at least 5 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  // City Dropdown
                  _buildCityDropdown(theme),
                  const SizedBox(height: 16),
                  // Description
                  _buildTextField(
                    controller: _descController,
                    hint: 'Description (amenities overview, guidelines...)',
                    maxLines: 3,
                    validator: (v) => v == null || v.length < 10 ? 'Description must be at least 10 characters' : null,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Operational Configurations',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Base Price
                  _buildTextField(
                    controller: _priceController,
                    hint: 'Base Rate per Hour (INR)',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final p = double.tryParse(v ?? '');
                      return p == null || p <= 0 ? 'Price must be a positive number' : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Timings
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _openController,
                          hint: 'Open Time (HH:MM)',
                          validator: (v) => v == null || !RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v) ? 'Format: HH:MM' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _closeController,
                          hint: 'Close Time (HH:MM)',
                          validator: (v) => v == null || !RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(v) ? 'Format: HH:MM' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                context.read<OwnerBloc>().add(
                                      RegisterTurfRequested(
                                        name: _nameController.text.trim(),
                                        description: _descController.text.trim(),
                                        address: _addressController.text.trim(),
                                        cityId: _selectedCityId,
                                        basePricePerHour: double.parse(_priceController.text.trim()),
                                        openingTime: _openController.text.trim(),
                                        closingTime: _closeController.text.trim(),
                                        images: const [
                                          'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=600&auto=format&fit=crop&q=80'
                                        ],
                                        amenities: const [
                                          'a0c1c2d3-e4f5-0123-4567-89abcdef0123', // WiFi seed
                                          'a1c1c2d3-e4f5-0123-4567-89abcdef0123'  // Parking seed
                                        ],
                                      ),
                                    );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('Register Turf Facility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          border: InputBorder.none,
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildCityDropdown(ThemeData theme) {
    final cities = [
      {'id': 'c0a37340-dfbd-497b-83c8-ee1bc7f0b5d9', 'name': 'Mumbai'},
      {'id': 'c1a27340-dfbd-497b-83c8-ee1bc7f0b5d9', 'name': 'Bangalore'},
      {'id': 'c2a27340-dfbd-497b-83c8-ee1bc7f0b5d9', 'name': 'Delhi'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedCityId,
          dropdownColor: const Color(0xFF151D30),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            border: InputBorder.none,
            errorStyle: TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
          items: cities.map((c) {
            return DropdownMenuItem<String>(
              value: c['id'],
              child: Text(c['name'] ?? ''),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCityId = val;
              });
            }
          },
        ),
      ),
    );
  }
}
