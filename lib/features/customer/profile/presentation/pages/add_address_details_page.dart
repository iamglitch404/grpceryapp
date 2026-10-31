import 'package:flutter/material.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';

class AddAddressDetailsPage extends StatefulWidget {
  final String locationDetails;
  final double latitude;
  final double longitude;

  const AddAddressDetailsPage({
    super.key, 
    required this.locationDetails,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddAddressDetailsPage> createState() => _AddAddressDetailsPageState();
}

class _AddAddressDetailsPageState extends State<AddAddressDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  late TextEditingController _locationController;
  final _houseController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.locationDetails);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _houseController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final addressData = {
        'label': 'Home',
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'street': _locationController.text.trim(),
        'details': _houseController.text.trim(),
        'is_default': true,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
      };

      final authHeaders = CubePod.get<AuthRepository>().authHeaders;
      final success = await CubePod.get<UserRepository>().addAddress(authHeaders, addressData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address saved successfully!')),
          );
          
          final fullAddress = '${_houseController.text}, ${_locationController.text}';
          // Pop back, returning the full address
          Navigator.pop(context, fullAddress);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save address.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Address Details',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Name'),
              _buildTextField(
                controller: _nameController,
                hint: 'e.g. John Doe',
                keyboardType: TextInputType.name,
                validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Phone Number'),
              _buildTextField(
                controller: _phoneController,
                hint: 'e.g. 9876543210',
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Location Area (from map)'),
              _buildTextField(
                controller: _locationController,
                hint: 'Map location',
                maxLines: 2,
                validator: (value) => value == null || value.isEmpty ? 'Please enter the location area' : null,
              ),
              const SizedBox(height: 20),
              
              _buildLabel('House / Flat / Block No.'),
              _buildTextField(
                controller: _houseController,
                hint: 'e.g. Flat 101, Block B',
                validator: (value) => value == null || value.isEmpty ? 'Please enter house details' : null,
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text(
                        'Save Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E8B57)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
